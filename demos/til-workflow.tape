Output demos/til-workflow.gif

Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# Today I Learned (TIL) Workflow"
Sleep 1s
Enter

Type "# Create a new TIL"
Sleep 500ms
Enter
Type "j til ocaml"
Sleep 500ms
Enter
Sleep 2s

# Simulate editing
Type "i"
Sleep 500ms
Type "## 2025-10-08"
Enter
Type "- Pattern matching is amazing for building CLIs"
Enter
Type "- Unix module provides great system integration"
Enter
Type "- OCaml compiles to fast native executables"
Sleep 1s

Escape
Type ":wq"
Enter
Sleep 1s

Type "# List your TILs"
Sleep 500ms
Enter
Type "j til list"
Sleep 500ms
Enter
Sleep 2s

Type "# Export to public repo"
Sleep 500ms
Enter
Type "j til export ocaml"
Sleep 500ms
Enter
Sleep 2s

Type "# List public TILs"
Sleep 500ms
Enter
Type "j til list --public"
Sleep 500ms
Enter
Sleep 2s
