{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE EmptyDataDecls #-}

module Main where

import Ambiguity
import System.Random
import System.Environment
import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Random.Class
import Network.Wai
import Network.Wai.Logger
import Network.Wai.Handler.Warp
import Servant
import Servant.Docs
import Servant.HTML.Lucid
import Lucid
import qualified Data.Text as T

import TextShow
import UI
import API
import Docs


instance MonadRandom Handler where
  getRandomR r = liftIO $ getRandomR r
  getRandom = liftIO getRandom
  getRandomRs r = liftIO $ getRandomRs r
  getRandoms = liftIO getRandoms


ambiguityServer :: Server SiteAPI
ambiguityServer = (finite :<|> realizations :<|> bits) :<|> serveDocs :<|> servePage 
  where finite :: FiniteData -> Handler (Headers '[Header "Content-Disposition" String] [Integer])
        finite (FiniteData samples low high shuffled offLow offHigh skip)
          = do ambi <- mkAmbiGen (1 / fromIntegral samples) 0.0001 offLow offHigh >>= ambiSkip skip
               values <- if shuffled
                         then generateShuffleR ambi samples (low, high)
                         else sequence $ generateR ambi samples (low, high)

               let filename = concat ["finite-", show samples, "-", show low, "-", show high, ".csv"]
               let header = concat ["filename=\"", filename, "\""]

               return $ addHeader header values


        bits :: FiniteData -> Handler (Headers '[Header "Content-Disposition" String] [Integer])
        bits (FiniteData samples low high shuffled offLow offHigh skip)
          = do cont <- mkContinuousState (1 / fromIntegral samples) 0.0001 offLow offHigh
               values <- if shuffled
                         then do bits <- shuffleAndTakeSeq (samples + skip) $ generateBits cont
                                 return $ map fromIntegral $ bits
                         else do bits <- sequence $ take (samples + skip) $ generateBits cont
                                 return $ map fromIntegral $ bits

               let filename = concat ["bits-", show samples, "-", show low, "-", show high, ".csv"]
               let header = concat ["filename=\"", filename, "\""]

               return $ addHeader header (drop skip values)


        realizations :: RealizationData -> Handler (Headers '[Header "Content-Disposition" String] [Double])
        realizations (RealizationData samples shuffled offLow offHigh skip)
          = do ambi <- mkAmbiGen (1 / fromIntegral samples) 0.0001 offLow offHigh >>= ambiSkip skip
               values <- if shuffled
                         then generateShuffle ambi samples
                         else sequence $ generate ambi samples

               let filename = concat ["realizations-", show samples, ".csv"]
               let header = concat ["filename=\"", filename, "\""]

               return $ addHeader header values

        servePage :: Handler (Html ())
        servePage = return $ homePage (safeLink api finiteAPI) (safeLink api realizationAPI)

        serveDocs :: Handler T.Text
        serveDocs = return . T.pack . markdown $ apiDocs


app :: Application
app = serve api ambiguityServer


main :: IO ()
main = do [port] <- fmap read <$> getArgs
          withStdoutLogger $ \aplogger -> do
            let settings = setPort port $ setLogger aplogger defaultSettings
            runSettings settings app
