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

# Path additions
fish_add_path -g /usr/local/bin
fish_add_path -g ~/.local/bin

# Interactive session customizations
if status is-interactive
    # Commands to run in interactive sessions can go here
end
