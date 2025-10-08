Output demos/project-search.gif

Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# Project Search with ripgrep + fzf"
Sleep 1s
Enter

Type "j project search 'handle_til'"
Sleep 500ms
Enter
Sleep 2s

# Simulate fzf interaction
Down
Sleep 300ms
Down
Sleep 300ms
Down
Sleep 300ms
Up
Sleep 500ms

Type "# Opens directly in nvim"
Sleep 1s
Enter
Sleep 2s
