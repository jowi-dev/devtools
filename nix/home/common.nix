{ config, pkgs, lib, ... }:

let
  j = import ../pkgs/j.nix { inherit pkgs; };
in
{
  home.stateVersion = "24.05";

  home.packages = [
    j
  ];
}
