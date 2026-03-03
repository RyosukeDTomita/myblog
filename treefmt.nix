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
  };

  settings.global.excludes = [
    "_site/*"
    ".stack-work/*"
    "dist-newstyle/*"
    ".git/*"
  ];
}
