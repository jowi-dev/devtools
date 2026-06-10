{ config, pkgs, lib, ... }:

let
  j = import ../pkgs/j.nix { inherit pkgs; };
in
{
  home.stateVersion = "24.05";

  home.packages = [
    j
    pkgs.ripgrep
    pkgs.fzf
    pkgs.bat
    pkgs.tmux
    pkgs.tree
    pkgs.nnn
    pkgs.direnv
    pkgs.mise
    pkgs.starship
    pkgs.universal-ctags
    pkgs.gcc # required for nvim-treesitter to compile parsers
    pkgs.tree-sitter # tree-sitter CLI (required for :TSInstall)

    # Language servers
    pkgs.beamPackages.expert # Elixir
    pkgs.lua-language-server
    pkgs.nixd
    pkgs.rust-analyzer
    pkgs.clang-tools # provides clangd
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    DEVTOOLS_ROOT = "${config.home.homeDirectory}/devtools";
    NIXOS_CONFIGS_ROOT = if pkgs.stdenv.isDarwin
      then "${config.home.homeDirectory}/Projects/nixos-configs"
      else "/etc/nixos/nixos-configs";
    FILE_EXPLORER = "nnn";
    MACHINE_TYPE = "personal";
  };

  # Neovim — plugins from nixpkgs, config from this repo
  # Plugins are submodules and won't be in the nix store, so we manage them here.
  # nvim-tag-stack is committed directly and is available from the store path.
  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      luasnip
      fzf-lua
      nvim-lspconfig
      nvim-tree-lua
      nvim-treesitter
      (pkgs.vimUtils.buildVimPlugin {
        name = "nvim-tag-stack";
        src = ./../../nvim/pack/plugins/start/nvim-tag-stack;
      })
    ];
  };

  # Link init.lua and lua config — don't link pack/ since plugins come from nixpkgs above
  xdg.configFile."nvim/init.lua".source = ./../../nvim/init.lua;
  xdg.configFile."nvim/lua".source = ./../../nvim/lua;

  # Starship prompt — loaded from this repo's starship.toml
  programs.starship = {
    enable = true;
    settings = lib.importTOML ./../../starship.toml;
  };

  # Fish shell
  programs.fish = {
    enable = true;
    shellAbbrs = {
      vim = "nvim";
      v = "nvim";
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph";
      gd = "git diff";
      dc = "docker-compose";
      d = "docker";
      gif = "chafa --animate=on --watch";
      # j shortcuts
      jps = "j project search";
      jpf = "j project files";
      jpe = "j project explore";
      jpl = "j plan";
      jplv = "j plan view";
      jpls = "j plan save";
      jtil = "j til";
      jtill = "j til list";
      jtils = "j til search";
      jw = "j work";
      jwn = "j work new";
    };
    interactiveShellInit = ''
      # direnv — auto-activate Nix shells
      if command -sq direnv
        direnv hook fish | source
      end

      # mise — tool version manager
      if command -sq mise
        mise activate fish | source
      end

      # Homebrew (macOS only)
      if test -d /opt/homebrew
        eval (/opt/homebrew/bin/brew shellenv)
      end
    '';
  };
}
