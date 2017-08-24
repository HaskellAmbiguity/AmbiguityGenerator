module Ambiguity where

import System.Random
import Data.ReinterpretCast
import Data.IntMap hiding (map, split)


-- | Draw a value from the cauchy distribution.
cauchyDraw :: Floating a => a -> a -> a -> a
cauchyDraw offset scale y = scale * tan (pi * (y - 1/2)) + offset


-- | State for an ambiguous number generator. Mostly this includes
--   parameters for the Cauchy distribution that we draw from at each
--   step (the offset, and scale). There are other parametrs for how
--   the scale changes over time, and some state for previous draws,
--   which are used as seeds for the ambiguity generator.
data AmbiGenState s =
  AmbiGenState { genOffset :: Double  -- ^ Offset for the cauchy distribution ("location").
               , genScale :: Double   -- ^ Scale for the cauchy distribution.
               , genPhi :: Double     -- ^ Small scaling factor for adjusting the scale.
               , genPsi :: Double     -- ^ Small scaling factor for adjusting the scale.
               , genSeed1 :: Double   -- ^ Last draw.
               , genSeed2 :: Double   -- ^ Second last draw.
               , genSeed3 :: Double   -- ^ Third last draw.
               , genSeed4 :: Double   -- ^ Fourth last draw.
               , genDraws :: Integer  -- ^ Number of draws.
               , genSource :: s       -- ^ Seed for uniform random number generation.
               }


instance Show (AmbiGenState s) where
  show (AmbiGenState offset scale phi psi seed1 seed2 seed3 seed4 numDraws source''')
    = "offset: " ++ show offset ++ ", scale: " ++ show scale ++ " seeds:" ++ show (seed1, seed2, seed3, seed4)


-- | Initialize the ambiguity generator.
--   This will also run the first couple of steps to get the seeds.
mkAmbiGen :: RandomGen s => s -> Double -> Double -> AmbiGenState s
mkAmbiGen source phi psi
  = AmbiGenState offset scale phi psi seed1 seed2 seed3 seed4 4 source''''
    where seed4 = cauchyDraw y 1 y'
          seed3 = cauchyDraw seed4 1 y''
          seed2 = cauchyDraw seed3 1 y'''
          seed1 = cauchyDraw seed2 1 y'''

          offset = seed2
          scale = phi * (abs seed1) + psi

          (y, source') = randomR (-100, 100) source
          (y', source'') = randomR (0, 1) source'
          (y'', source''') = randomR (0, 1) source'
          (y''', source'''') = randomR (0, 1) source'


-- | Generate an ambiguous Double, and the next state of the ambiguity generator.
nextAmbi :: RandomGen s => AmbiGenState s -> (Double, AmbiGenState s)
nextAmbi (AmbiGenState offset scale phi psi seed1 seed2 seed3 seed4 numDraws source)
  = (draw', nextGen)
    where draw = cauchyDraw scale offset y
          (y, source') = randomR (0, 1) source

          threshold = 10**3

          rescale = if seed1 > threshold
                    then if (floor seed3) `mod` 2 == 0 then True else False
                    else False

          offset' = if rescale
                    then 1 / (abs seed4 + 1)
                    else seed1

          scale' = if rescale
                   then phi / (abs seed3 + psi) + psi
                   else phi * abs seed2 + psi

          draw' = if rescale then 1/draw else draw
          nextGen = AmbiGenState offset' scale' phi psi draw' seed1 seed2 seed3 (numDraws+1) source'


generate :: RandomGen s => AmbiGenState s -> Integer -> [Double]
generate _ 0 = []
generate ambi n = r : generate ambi' (n-1)
  where (r, ambi') = nextAmbi ambi


generateR :: RandomGen s => AmbiGenState s -> Integer -> (Integer, Integer) -> [Integer]
generateR ambi n range@(lo, hi)
  | lo > hi = generateR ambi n (hi, lo)
  | otherwise = map (toRange range) (generate ambi n)


toRange :: (Integer, Integer) -> Double -> Integer
toRange (lo, hi) x = floor x `mod` (hi - lo + 1) + lo


-- | RandomGen instance for the ambiguity generator.
--   This currently has a few problems.
--
--   1) We just recast the double as an integer. Could add bias.
--   2) The split method isn't really well founded. Generator would
--      probably still be in the same "phase" when split, yielding
--      similar results.
instance RandomGen s => RandomGen (AmbiGenState s) where
  next g = (fromIntegral $ doubleToWord y, g')
    where (y, g') = nextAmbi g

  split (AmbiGenState offset scale phi psi seed1 seed2 seed3 seed4 numDraws source)
    = (AmbiGenState offset scale phi psi seed2 seed1 seed4 seed3 numDraws s1, AmbiGenState offset scale phi psi seed1 seed2 seed3 seed4 numDraws s2)
      where (s1, s2) = split source


zeroMap :: Integer -> IntMap Int
zeroMap range = fromList [(x, 0) | x <- [1 .. fromIntegral range]]


countMap :: Integer -> [Int] -> IntMap Int
countMap range ls = Prelude.foldr (adjust (+1)) (zeroMap range) ls


drawCount :: Integer -> Integer -> (StdGen -> Integer -> Integer -> [Integer]) -> IO (IntMap Int)
drawCount range num generator
  = do source <- newStdGen
       let draw = generator source num range

       return (countMap range (map fromIntegral draw))


countToHistogram :: IntMap Int -> [Int]
countToHistogram = map snd . toAscList


drawHistogram :: Integer -> Integer -> (StdGen -> Integer -> Integer -> [Integer]) -> IO [Int]
drawHistogram range num generator
  = fmap countToHistogram (drawCount range num generator)


proportion :: Integer -> [Int] -> Float
proportion y (x : xs) = fromIntegral x / fromIntegral y


paperGen :: StdGen -> Integer -> Integer ->  [Integer]
paperGen s n range
  = generateR (mkAmbiGen s (1 / fromIntegral n) 0.0001) n (1, fromIntegral range)


haskellGen :: StdGen -> Integer -> [Integer]
haskellGen s n
  = take (fromIntegral n) $ randomRs (1, 100) (mkAmbiGen s 0.0001 0.0001)
