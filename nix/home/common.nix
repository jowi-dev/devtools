# `tskmstr`, `vdiff-nvim`, and `vdiff` are provided via extraSpecialArgs when
# this repo's flake builds the home config. Consumers that import this module
# directly (e.g. the system-wide nixos-configs flake) may not provide them, so
# they default to null and are skipped.
{ config, pkgs, lib, tskmstr ? null, vdiff-nvim ? null, vdiff ? null, ... }:

let
  j = import ../pkgs/j.nix { inherit pkgs; };
  graphify = import ../pkgs/graphify.nix { inherit pkgs; };
  # graphify is absent from some nixpkgs pins (e.g. NixOS's system nixpkgs);
  # skip it gracefully instead of failing evaluation.
  graphifyPackages = lib.warnIf (graphify == null)
    "graphify unavailable in this nixpkgs pin — omitting it from home.packages"
    (lib.optional (graphify != null) graphify);
  # tskmstr is passed via extraSpecialArgs; skip it when a consumer imports this
  # module without providing it (see the default above).
  tskmstrPackages = lib.warnIf (tskmstr == null)
    "tskmstr not provided (imported without extraSpecialArgs) — omitting it from home.packages"
    (lib.optional (tskmstr != null) tskmstr.packages.${pkgs.system}.default);
  # vdiff is passed via extraSpecialArgs; skip it when a consumer imports this
  # module without providing it (see the default above).
  vdiffPackages = lib.warnIf (vdiff == null)
    "vdiff not provided (imported without extraSpecialArgs) — omitting it from home.packages"
    (lib.optional (vdiff != null) vdiff.packages.${pkgs.system}.default);
in
{
  home.stateVersion = "24.05";

  home.packages = graphifyPackages ++ tskmstrPackages ++ vdiffPackages ++ [
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

  # Neovim — most plugins come from nixpkgs (pkgs.vimPlugins below). Two are
  # built from source instead: nvim-tag-stack is plain files committed
  # directly in this repo (nvim/pack/plugins/start/nvim-tag-stack), and
  # vdiff.nvim is fetched via the vdiff-nvim flake input (it has no flake.nix
  # of its own, hence `flake = false` on the input). nvim/pack/plugins/start/
  # itself is not linked into ~/.config/nvim — only its nvim-tag-stack
  # subdirectory is consumed, as a buildVimPlugin src.
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
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
    ] ++ lib.optional (vdiff-nvim != null) (pkgs.vimUtils.buildVimPlugin {
      name = "vdiff.nvim";
      src = vdiff-nvim;
    });
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
