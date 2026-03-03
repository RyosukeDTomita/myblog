{
  description = "Hakyll blog with Nix, Stack, and GitHub Pages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    treefmt-nix,
  }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.zsh
            pkgs.stack
            pkgs.treefmt
            pkgs.ormolu
            pkgs.python3Packages.mdformat
            pkgs.haskell.packages.ghc96.ghc
            pkgs.haskell.packages.ghc96.cabal-install
            pkgs.haskell.packages.ghc96.haskell-language-server
          ];
        };
      }
    );
}
