# Homebrew setup
if test -d /opt/homebrew
    eval (/opt/homebrew/bin/brew shellenv)
end

# mise (tool version manager)
if command -v mise &> /dev/null
    mise activate fish | source
end

# Starship prompt
if command -v starship &> /dev/null
    starship init fish | source
end

# Environment variables
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx DEVTOOLS_ROOT /Users/jowi/devtools
set -gx NIXOS_CONFIGS_ROOT /Users/jowi/Projects/nixos-configs

set -gx FILE_EXPLORER nnn
set -gx MACHINE_TYPE personal

# Abbreviations (expand on space)
abbr -a vim nvim
abbr -a v nvim
abbr -a g git
abbr -a gs git status
abbr -a ga git add
abbr -a gc git commit
abbr -a gp git push
abbr -a gl git log --oneline --graph
abbr -a gd git diff
abbr -a dc docker-compose
abbr -a d docker
abbr -a gif chafa --animate=on --watch

# j command shortcuts
abbr -a jps j project search
abbr -a jpf j project files
abbr -a jpe j project explore
abbr -a jpl j plan
abbr -a jplv j plan view
abbr -a jpls j plan save
abbr -a jtil j til
abbr -a jtill j til list
abbr -a jtils j til search

# Path additions
fish_add_path -g /usr/local/bin
fish_add_path -g ~/.local/bin

# Interactive session customizations
if status is-interactive
    # Commands to run in interactive sessions can go here
end
