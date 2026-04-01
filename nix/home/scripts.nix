{ config, pkgs, lib, ... }:

{
  xdg.configFile."tmux/scripts/tmux-session-picker.sh" = {
    source = ../../scripts/tmux-session-picker.sh;
    executable = true;
  };
}
