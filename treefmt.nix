{ ... }:
{
  projectRootFile = "flake.nix";

  programs.ormolu = {
    enable = true;
    includes = [ "*.hs" ];
  };

  programs.mdformat = {
    enable = true;
    includes = [ "*.md" ];
    excludes = [ "posts/*.md" ];
  };

  settings.global.excludes = [
    "_site/*"
    ".stack-work/*"
    "dist-newstyle/*"
    ".git/*"
  ];
}
