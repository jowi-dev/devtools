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

### Environment Management
```bash
# Install tools via Homebrew (run after updating Brewfile)
brew bundle

# Install mise-managed tools (Elixir, etc.)
mise install

# Check Neovim configuration health
nvim
# Then run: :checkhealth
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
- Homebrew for macOS package management
- mise for language runtime management (currently Elixir)
- Starship for enhanced shell prompting
- Fish shell as the primary shell
- Git submodules for modular configuration components

The templates system allows quick project initialization with pre-configured development environments for different languages and frameworks.