{
  description = "haskell site";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/25.05";
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

        # デフォルトのパッケージセット(GHC 9.8.4)を使う。
        # Hydraがビルド保証(キャッシュ)しているのはデフォルトセットだけなので、
        # ghc9102などを明示指定するとhakyll/pandoc一式がCIで毎回フルコンパイルになる。
        hpkgs = pkgs.haskellPackages;

        # site.hsを変更していない限りHaskellの再コンパイルを避けるため、
        # ビルドに必要なファイルだけをsrcにする(posts/を編集してもキャッシュが効く)。
        siteSrc = pkgs.lib.sourceByRegex ./. [
          "^site\\.hs$"
          "^myblog\\.cabal$"
        ];
        siteBin = hpkgs.callCabal2nix "site" siteSrc { };

        # mermaidはgit管理せずビルド時に取得する(3.5MBあるため)。
        # バージョンを上げるときは scripts/fetch-mermaid.sh のMERMAID_VERSIONも揃えること。
        mermaidVersion = "11.16.1";
        mermaidJs = pkgs.fetchurl {
          url = "https://cdn.jsdelivr.net/npm/mermaid@${mermaidVersion}/dist/mermaid.min.js";
          hash = "sha256-GDJ773DZb7UF/nKH2fanNi6/B/9ldt36/7Ggbz4aKVQ=";
        };

        site = pkgs.runCommand "myblog-site" {
          nativeBuildInputs = [ siteBin ];
          LANG = "C.UTF-8";
          LC_ALL = "C.UTF-8";
        } ''
          cp -r ${self} source
          chmod -R u+w source
          cd source
          cp ${mermaidJs} js/mermaid.min.js
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
