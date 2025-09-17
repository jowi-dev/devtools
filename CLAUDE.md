# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal development environment configuration repository focused on Nix-based tooling and cross-platform setup. The repository manages:

- Development tooling via Homebrew (macOS) and mise
- Neovim configuration with custom Lua modules
- Shell configuration (Fish shell with Starship prompt)
- Development templates for various programming languages
- Git submodules for logging and Neovim plugins

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
# Build WSL Nix configuration
make wsl
```

## Architecture

### Configuration Structure
- `/nvim/` - Complete Neovim configuration with Lua modules for keybindings, options, package config, language support, and aliases
- `/templates/` - Nix flake templates for different development environments
- `/logs/` - Git submodule for personal logging
- Root level config files: `Brewfile`, `mise.toml`, `starship.toml`

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
- **j command** for config synchronization across machines
- **Starship** for enhanced shell prompting
- **Fish shell** as the primary shell
- **Git submodules** for modular configuration components

The templates system allows quick project initialization with pre-configured development environments for different languages and frameworks.

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
- Can you remember the previous message about next feature suggestions? They're pretty good
- ⏺ Absolutely! This is a solid MVP - you've built a really elegant system. Here are some potential next features, roughly ordered by what I think would be most valuable:

  High Value, Low Effort

  1. j status command - Show which configs are out of sync between repo and system
  2. j diff <package> - Preview changes before import/export
  3. Bash completion - Tab completion for package names and commands

  Quality of Life

  4. j list or j ls - Just show available packages (cleaner than help)
  5. Config validation - Check if system has required tools (delta, fish, etc.) before export
  6. j backup / j restore - Manage the .backup files created during operations

  Power User Features

  7. Profile support - j export --profile work for different machine types (work/personal)
  8. Selective sync - j export nvim --exclude plugins for partial syncing
  9. Remote sync - j pull remote-machine to sync from another machine via SSH

  Advanced

  10. Config templating - Variables like {{username}} in configs
  11. Dependency tracking - Know which configs depend on which tools
  12. Integration with existing dotfile managers - Import from chezmoi, stow, etc.