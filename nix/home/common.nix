# `tskmstr`, `thatch`, `vdiff-nvim`, `vdiff`, and `pckr` are provided via
# extraSpecialArgs when this repo's flake builds the home config. Consumers that
# import this module directly (e.g. the system-wide nixos-configs flake) may not
# provide them, so they default to null and are skipped.
{ config, pkgs, lib, tskmstr ? null, thatch ? null, vdiff-nvim ? null, vdiff ? null, pckr ? null, ... }:

let
  j = import ../pkgs/j.nix { inherit pkgs; };
  graphify = import ../pkgs/graphify.nix { inherit pkgs; };
  # AI harnesses are pinned to official upstream release binaries in
  # nix/pkgs/ai-sources.json (bump with scripts/update-ai-sources.sh) instead
  # of pkgs.claude-code/pkgs.opencode, which lag upstream releases.
  claude-code = import ../pkgs/claude-code.nix { inherit pkgs; };
  opencode = import ../pkgs/opencode.nix { inherit pkgs; };
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
  # thatch is passed via extraSpecialArgs; skip it when a consumer imports this
  # module without providing it (see the default above).
  #
  # depsHash is overridden here rather than trusted from upstream: the
  # node_modules FOD hash depends on both bun.lock AND the bun version doing
  # the install, so upstream's pinned hashes (regenerated only on their build
  # platform) routinely go stale for aarch64-darwin. When a thatch bump fails
  # with "hash mismatch in fixed-output derivation ...thatch-node-modules...",
  # copy the "got:" hash from the error over the matching entry below.
  thatchDepsHash = {
    x86_64-linux = "sha256-FETtq7n3Q/e2bD0belKNpzSvsmVXcuefBV456axlLpo=";
    aarch64-darwin = "sha256-Ml4tjJa5ZmgQEl5yZInT8qSyThFVsnsotrKI/rmb2XU=";
  };
  thatchPackages = lib.warnIf (thatch == null)
    "thatch not provided (imported without extraSpecialArgs) — omitting it from home.packages"
    (lib.optional (thatch != null)
      ((thatch.packages.${pkgs.system}.default).override { depsHash = thatchDepsHash; }));
  # vdiff is passed via extraSpecialArgs; skip it when a consumer imports this
  # module without providing it (see the default above).
  vdiffPackages = lib.warnIf (vdiff == null)
    "vdiff not provided (imported without extraSpecialArgs) — omitting it from home.packages"
    (lib.optional (vdiff != null) vdiff.packages.${pkgs.system}.default);
  # pckr is passed via extraSpecialArgs; skip it when a consumer imports this
  # module without providing it (see the default above).
  pckrPackages = lib.warnIf (pckr == null)
    "pckr not provided (imported without extraSpecialArgs) — omitting it from home.packages"
    (lib.optional (pckr != null) pckr.packages.${pkgs.system}.default);
in
{
  home.stateVersion = "24.05";

  home.packages = graphifyPackages ++ tskmstrPackages ++ thatchPackages ++ vdiffPackages ++ pckrPackages ++ [
    j
    pkgs.ripgrep
    pkgs.fzf
    pkgs.bat
    pkgs.tree
    pkgs.nnn
    pkgs.direnv
    pkgs.mise
    pkgs.starship
    pkgs.universal-ctags
    pkgs.gcc # required for nvim-treesitter to compile parsers
    pkgs.tree-sitter # tree-sitter CLI (required for :TSInstall)
    pkgs.jq
    pkgs.curl
    pkgs.delta # git delta

    # AI coding harnesses
    claude-code
    opencode

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
    # Enables thatch's async fact extraction in opencode — child sessions run
    # in the background instead of blocking the turn. Consumed by the
    # @jeffober/thatch opencode plugin (see opencode/opencode.json).
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
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

  # Tmux — config lives in this repo's .tmux.conf. programs.tmux installs the
  # tmux package and writes ~/.config/tmux/tmux.conf. The shell is derived from
  # Nix so it resolves correctly on both NixOS and nix-darwin (no hardcoded
  # /opt/homebrew path). sensibleOnTop is off because .tmux.conf is self-contained.
  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    shell = "${pkgs.fish}/bin/fish";
    extraConfig = builtins.readFile ./../../.tmux.conf;
  };

  # Plugin/hook scripts referenced by @picker_refresh_cmd and Claude Code
  # hooks (claude-picker-attention.sh, phoenix-picker-server.sh) at
  # ~/.config/tmux/scripts/. The session picker itself (bind s / bind g) is
  # the pckr flake input, not a script in this repo.
  xdg.configFile."tmux/scripts".source = ./../../scripts;

  # opencode (AI coding agent) — config lives in this repo but is linked
  # out-of-store so model edits in opencode/opencode.json take effect live
  # without a home-manager rebuild. The Venice API key is NOT in this file;
  # it is supplied via `opencode auth login` (stored in ~/.local/share/opencode/auth.json).
  xdg.configFile."opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/devtools/opencode/opencode.json";

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

      # venice-models — list Venice.ai text models (reads key from opencode auth)
      function venice-models --description 'List Venice.ai text model IDs'
        set -l auth "$HOME/.local/share/opencode/auth.json"
        if not test -f "$auth"
          echo "No opencode auth found. Run: opencode auth login  (pick Venice.ai)" >&2
          return 1
        end
        set -l key (jq -r '.venice.key // empty' "$auth" 2>/dev/null)
        if test -z "$key"
          echo "No Venice key in $auth. Run: opencode auth login" >&2
          return 1
        end
        curl -s https://api.venice.ai/api/v1/models -H "Authorization: Bearer $key" \
          | jq -r '.data[] | select(.type=="text") | .id'
      end
    '';
  };
}
