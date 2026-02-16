# TODO: Verify Claude Export Configuration

## Context
We've added new Claude-related files and want to ensure `j export claude` properly exports everything.

## Current Configuration

In `common.ml` line 12:
```ocaml
("claude", "claude", Filename.concat (Sys.getenv "HOME") ".claude");
```

This maps:
- **Source**: `~/devtools/claude/`
- **Destination**: `~/.claude/`

## What Should Be Exported

The `claude/` directory now contains:
```
claude/
├── CLAUDE.md                       # User-level, language-agnostic principles
├── agents/                         # Global agents
│   ├── elixir-codebase-advisor.md
│   ├── elixir-coding-guide.md
│   ├── document-elixir-module.md   # ← Moved from axiom
│   └── product-roadmap-advisor.md
└── skills/                         # ← NEW! Global skills
    ├── tdd-red.md                  # Language-agnostic templates
    ├── tdd-green.md
    ├── tdd-refactor.md
    ├── commit-checkpoint.md
    ├── audit.md
    ├── test-red-elixir.md          # Elixir implementations
    ├── implement-elixir.md
    ├── refactor-elixir.md
    ├── audit-elixir.md
    └── commit-checkpoint-elixir.md
```

## Testing Steps

1. **Test current export:**
   ```bash
   j export claude
   ```

2. **Verify all files copied:**
   ```bash
   ls -R ~/.claude/
   # Should show:
   # - CLAUDE.md
   # - agents/ with all 4 agent files
   # - skills/ with all 10 skill files
   ```

3. **Check file contents:**
   ```bash
   cat ~/.claude/CLAUDE.md
   cat ~/.claude/skills/test-red-elixir.md
   ```

4. **Test on fresh machine:**
   - Clone devtools to new machine
   - Run `j export claude`
   - Verify Claude Code picks up all skills and agents

## Expected Behavior

Since `copy_recursive` in `common.ml` uses `rsync -a` for directories (line 73), it should:
- ✅ Copy entire `claude/` directory recursively
- ✅ Include all subdirectories (`agents/`, `skills/`)
- ✅ Include all files within subdirectories
- ✅ Preserve directory structure

## Potential Issues

None expected - the current configuration should handle this correctly.

The `copy_recursive` function handles both files and directories, and uses `rsync -a` for directories which is perfect for our needs.

## Status

- [ ] Test `j export claude` on current machine
- [ ] Verify all 15 files exported correctly (1 CLAUDE.md + 4 agents + 10 skills)
- [ ] Test that Claude Code recognizes the skills
- [ ] Document any issues found
- [ ] Update this TODO or delete if everything works

## Resolution

Once verified working, delete this file:
```bash
rm ~/devtools/TODO_CLAUDE_EXPORT.md
```
