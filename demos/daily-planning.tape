Output demos/daily-planning.gif

Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# Daily Planning Workflow"
Sleep 1s
Enter

Type "j plan"
Sleep 500ms
Enter
Sleep 2s

# Simulate editing in nvim
Type "i"
Sleep 500ms
Type "## Goals"
Enter
Type "- [ ] Build awesome devtools"
Enter
Type "- [ ] Write documentation"
Enter
Type "- [ ] Ship it!"
Sleep 1s

Escape
Type ":wq"
Enter
Sleep 1s

Type "# View today's plan"
Sleep 500ms
Enter
Type "j plan view"
Sleep 500ms
Enter
Sleep 3s

Type "# Save to git"
Sleep 500ms
Enter
Type "j plan save"
Sleep 500ms
Enter
Sleep 2s
