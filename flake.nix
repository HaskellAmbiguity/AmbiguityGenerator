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
      in rec {
        defaultPackage =
          pkgs.haskellPackages.callCabal2nixWithOptions "ambiguity-server" ./. "" {};

        packages = {
          default = defaultPackage;
        };

        apps = rec {
          ambiguity-server = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/ambiguity-server";
          };

          histogram = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/histogram";
          };

          draws = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/draws";
          };

          default = ambiguity-server;
        };

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
