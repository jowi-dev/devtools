Output demos/config-sync.gif

Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# Config Sync Workflow"
Sleep 1s
Enter

Type "# View available packages"
Sleep 500ms
Enter
Type "j"
Sleep 500ms
Enter
Sleep 3s

Type "# Export fish config to system"
Sleep 500ms
Enter
Type "j export fish"
Sleep 500ms
Enter
Sleep 2s

Type "# Export all configs"
Sleep 500ms
Enter
Type "j export --all"
Sleep 500ms
Enter
Sleep 3s

Type "# Import changes from system"
Sleep 500ms
Enter
Type "j import nvim"
Sleep 500ms
Enter
Sleep 2s
