# My Dev Environment

## Elevator Pitch
You're an avid OSS contributor with a day job. You have a work computer courtesy of your company and Apple, and a personal computer that's Linux. You install a shiny new monitoring tool at home, then go to work and... no surprises, it's not there. You install it manually at work. Rinse and repeat for every single tool, all 30 of them. You go on a job hunt, get a new Mac, boom! All of that setup on your old work laptop is gone.

Wouldn't it be great to have a development environment that grows with you instead of holding you back? This repository provides exactly that - a cross-platform development environment that synchronizes seamlessly across all your machines.

## What You Get

- **Cross-platform tooling** via Homebrew (macOS) and mise
- **Complete Neovim configuration** with custom Lua modules
- **Enhanced shell experience** with Fish shell and Starship prompt
- **Development templates** for various programming languages via Nix flakes
- **Config synchronization** with the `j` command to keep environments in sync
- **One-command setup** that gets you from zero to fully configured development environment

## Quick Start

### New Machine Setup
```bash
# Clone this repository
git clone <your-repo-url>
cd devtools

# Install everything and deploy configs
make install

# Your entire development environment is ready!
```

That's it! The `make install` command:
- Installs Homebrew (if needed on macOS)
- Installs all tools from the Brewfile
- Sets up mise with language runtimes (Elixir, OCaml, etc.)
- Builds and installs the `j` command globally for config management
- Deploys all configurations to their system locations

### Verify Installation
```bash
# Check Neovim configuration health
nvim
# Then run: :checkhealth
```

## Key Commands

### Environment Management
```bash
# Install tools via Homebrew (after updating Brewfile)
brew bundle

# Install mise-managed language runtimes
mise install
```

### Config Synchronization (j command)
The `j` command keeps your configs in sync across machines:

```bash
# Export all configs from repo to system (great for new machine setup)
j export --all

# Import specific config from system to repo
j import nvim

# Export specific config from repo to system  
j export fish

# Force operations (skip timestamp checks)
j --force export starship

# Install j command globally (if needed)
j install
```

### Development Templates
Quick project initialization with pre-configured environments:

```bash
# List available templates
nix flake show

# Initialize projects from templates
nix flake init -t .#bash           # Basic bash script template
nix flake init -t .#elixir-phoenix # Phoenix/Elixir web development
nix flake init -t .#elixir-script  # Basic Elixir scripting
nix flake init -t .#odin          # Odin graphics development
```

## Architecture

### Configuration Structure
- `/nvim/` - Complete Neovim configuration with modular Lua setup
- `/templates/` - Nix flake templates for different development environments
- `/logs/` - Git submodule for personal logging
- Root level configs: `Brewfile`, `mise.toml`, `starship.toml`

### The `j` Command
A custom tool for configuration management that:
- Synchronizes configs between your repository and system locations
- Handles backups automatically
- Supports force operations and selective sync
- Keeps track of modification timestamps to prevent accidental overwrites

### Neovim Configuration  
Modularized in `/nvim/lua/`:
- `keybindings.lua` - Custom key mappings
- `opts.lua` - Editor options and settings
- `package_config.lua` - Plugin configurations  
- `languages.lua` - Language-specific settings
- `aliases.lua` - Command aliases

### Development Workflow
This environment supports cross-platform development with:
- **Homebrew** for macOS package management
- **mise** for language runtime management
- **j command** for seamless config synchronization
- **Starship** for enhanced shell prompting
- **Fish shell** as the primary shell
- **Nix flake templates** for quick project initialization

## Prerequisites

### macOS
- Git (install via Xcode command line tools: `xcode-select --install`)

### Linux  
- Git
- curl or wget
- Basic build tools (usually available by default)

The `make install` command will handle installing everything else, including Homebrew on macOS.

## Workflow

1. **Initial setup**: Clone repo, run `make install`
2. **Daily use**: Your environment is ready across all machines
3. **Adding tools**: Update `Brewfile` or `mise.toml`, then run `brew bundle` or `mise install`
4. **Config changes**: Make changes in repo, then `j export <package>` to deploy
5. **New machine**: Just `git pull && j export --all`

Your development environment now grows with you, not against you!