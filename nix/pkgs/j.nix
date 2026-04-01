{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "j";
  version = "0.1.0";

  src = pkgs.lib.cleanSourceWith {
    src = ../..;
    filter = path: type:
      let
        baseName = builtins.baseNameOf path;
      in
      builtins.match ".*\\.ml$" baseName != null;
  };

  nativeBuildInputs = [ pkgs.ocaml ];

  buildPhase = ''
    ocamlopt -I +unix unix.cmxa -o j \
      common.ml config.ml nvim.ml project.ml plan.ml til.ml work.ml remote.ml j.ml
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp j $out/bin/
  '';

  meta = {
    description = "Jowi's dev environment sync tool";
    mainProgram = "j";
  };
}
