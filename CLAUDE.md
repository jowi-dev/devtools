# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal development environment configuration repository focused on Nix-based tooling and cross-platform setup. The repository manages:

- Development tooling via Homebrew (macOS) and mise
- Neovim configuration with custom Lua modules
- Shell configuration (Fish shell with Starship prompt)
- Development templates for various programming languages
- A git submodule (`public_logs`) for published logs

## Key Commands

### Initial Setup
```bash
# Complete system setup (installs everything and deploys configs)
make install
```

### Environment Management
```bash
# Install tools via Homebrew (run after updating Brewfile)
brew bundle

# Install mise-managed tools (Elixir, OCaml, etc.)
mise install

# Check Neovim configuration health
nvim
# Then run: :checkhealth
```

### Config Sync (j command)
```bash
# Import config from system to repo
j import <package>

# Export config from repo to system
j export <package>

# Export all configs to system (great for new machine setup)
j export --all

# Force operations (skip timestamp checks)
j --force import <package>

# Install j command globally
j install
```

### Daily Planning & Logging
```bash
# Edit today's plan
j plan
# Fish abbreviation: jpl

# View today's plan
j plan view
# Fish abbreviation: jplv

# List recent plans
j plan list [n]

# Edit specific date
j plan 2025-10-08

# Commit and push logs
j plan save
# Fish abbreviation: jpls
```

### Today I Learned (TIL)
```bash
# Edit private TIL
j til <topic>
# Fish abbreviation: jtil

# List private TILs
j til list
# Fish abbreviation: jtill

# List public TILs
j til list --public

# Search TILs
j til search <pattern>
# Fish abbreviation: jtils

# Polish and export to public repo
j til export <topic>
```

### Project Search
```bash
# Search files with ripgrep + fzf, open in nvim
j project search [pattern]
# Fish abbreviation: jps
```

### AI Harness Updates (claude-code, opencode)
```bash
# Bump both pins to the latest official upstream releases
# (rewrites nix/pkgs/ai-sources.json using upstream-published checksums)
scripts/update-ai-sources.sh

# Then review, commit, and apply
git diff nix/pkgs/ai-sources.json
make switch
```

These two packages are deliberately NOT taken from nixpkgs (packaging lag) or
Homebrew — they are pinned to official release binaries in
`nix/pkgs/ai-sources.json`, consumed by `nix/pkgs/claude-code.nix` and
`nix/pkgs/opencode.nix`.

### Nix Templates
```bash
# List available templates
nix flake show

# Initialize project from template
nix flake init -t .#bash           # Basic bash script template
nix flake init -t .#elixir-phoenix # Phoenix/Elixir web development
nix flake init -t .#elixir-script  # Basic Elixir scripting
nix flake init -t .#odin          # Odin graphics development
```

### Build Commands (from Makefile)
```bash
# Build the j CLI (dune build inside nix develop, copies binary to ./j)
make j
```

## Architecture

### Configuration Structure
- `/nvim/` - Complete Neovim configuration with Lua modules for keybindings, options, package config, language support, and aliases
- `/templates/` - Nix flake templates for different development environments
- `/logs/` - Private logging repo, cloned locally at the repo root (not tracked here; used by `j plan`/`j til` for dailies, work notes, projects, private TILs)
- `/public_logs/` - Public git submodule for published content (polished TILs, blog posts); the only registered submodule
- Root level config files: `Brewfile`, `mise.toml`, `starship.toml`, `fish/config.fish`

### Logging Structure
**Private (`logs/` - local clone of git@github.com:jowi-dev/logs.git, not a registered submodule):**
- `dailies/` - Daily plans and retrospectives with Goals/Notes/Done sections
- `work/` - Work-related notes, 1-1s, performance reviews
- `projects/` - Project-specific notes and planning
- `til/` - Private, rough Today I Learned notes (working drafts)

**Public (`public_logs/` submodule - git@github.com:jowi-dev/logs_external.git):**
- `til/` - Polished, public-ready TIL articles
- Future: blog posts, tutorials, etc.

**Workflow:**
1. Write rough notes in private `logs/til/`
2. Polish with `j til export <topic>` - opens editor, then copies to `public_logs/til/`
3. Commit private changes with `j plan save`
4. Commit public changes separately in `public_logs/`

### Neovim Setup
The Neovim configuration is modularized in `/nvim/lua/`:
- `keybindings.lua` - Custom key mappings
- `opts.lua` - Editor options and settings  
- `package_config.lua` - Plugin configurations
- `languages.lua` - Language-specific settings
- `aliases.lua` - Command aliases

### Development Workflow
This environment supports cross-platform development with:
- **Homebrew** for macOS package management
- **mise** for language runtime management (Elixir, OCaml)
- **j command** for config synchronization and logging workflow
- **Starship** for enhanced shell prompting
- **Fish shell** as the primary shell with abbreviations for common commands
- **Git submodule** (`public_logs`) for published log content

The templates system allows quick project initialization with pre-configured development environments for different languages and frameworks.

**Key Environment Variables:**
- `DEVTOOLS_ROOT` - Path to this repo, set automatically by `make install` in fish config
- `EDITOR` - Set to `nvim` in fish config

### New Machine Setup
1. Clone this repository
2. Run `make install` 
3. Your entire development environment is ready!

The install process:
- Installs Homebrew (if needed)
- Installs all tools from Brewfile
- Sets up mise with language runtimes
- Builds and installs the j command globally
- Deploys all configs to system locations