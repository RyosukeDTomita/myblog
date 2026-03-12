{
  description = "haskell site";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.05";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    treefmt-nix,
  }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        hpkgs = pkgs.haskell.packages.ghc96;
        siteBin = hpkgs.callCabal2nix "site" ./. { };
        site = pkgs.runCommand "myblog-site" {
          nativeBuildInputs = [ siteBin ];
          LANG = "C.UTF-8";
          LC_ALL = "C.UTF-8";
        } ''
          cp -r ${self} source
          chmod -R u+w source
          cd source
          site build
          cp -r _site "$out"
        '';
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        packages.site = site;
        packages.default = site;

        devShells.default = hpkgs.shellFor {
          packages = p: [ siteBin ];

          buildInputs = [
            pkgs.cabal-install
            pkgs.haskell-language-server
            pkgs.ghcid
            pkgs.pinact
          ];

          withHoogle = true;
        };
      });
}
