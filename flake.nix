{
  description = "Ambiguous random number generation in Haskell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ ]; };

        version = "AmbiguityGenerator:master";
      in {
        defaultPackage =
          pkgs.haskellPackages.callCabal2nixWithOptions "ambiguity-server" ./. "" {};

        devShell = pkgs.haskellPackages.shellFor {
          packages =
            p: [ self.defaultPackage.${system} ];
          buildInputs = with pkgs; [
            haskellPackages.haskell-language-server # you must build it with your ghc to work
            ghcid
            cabal-install
            haskellPackages.ghc-core
          ];
          withHoogle=true;
        };
      });
}
