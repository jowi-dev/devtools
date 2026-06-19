{ pkgs }:

pkgs.ocamlPackages.buildDunePackage {
  pname = "j";
  version = "0.1.0";

  src = pkgs.lib.cleanSourceWith {
    src = ../..;
    filter = path: type:
      let
        baseName = builtins.baseNameOf path;
      in
      builtins.match ".*\\.ml$" baseName != null
        || baseName == "dune"
        || baseName == "dune-project";
  };

  meta = {
    description = "Jowi's dev environment sync tool";
    mainProgram = "j";
  };
}
