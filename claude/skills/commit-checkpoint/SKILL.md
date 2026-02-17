---
name: commit-checkpoint
description: Create quick checkpoint commits for incremental progress (save point philosophy)
---

# Commit Checkpoint (Language-Agnostic Template)

## Purpose
Create a quick checkpoint commit for incremental progress - treating commits like save points in a game.

This implements the **checkpoint/bonfire philosophy**: commit whenever you've made usable progress, not just when "done."

## Philosophy

Think of commits as:
- **Video game checkpoints** - Save after each room, not after the dungeon
- **Dark Souls bonfires** - Rest whenever you find one
- **Database transactions** - Frequent small commits for rollback safety
- **Snapshots** - Capture working state often

**The rule:** If you can describe the change in one sentence, commit it.

## When to Use This Skill

**Commit checkpoint when you've:**
- Added one new function (with test)
- Fixed one bug
- Refactored one module
- Updated one config file
- Added one section to documentation
- Made any change that leaves code in a **usable, improved state**

**Don't commit when:**
- Code doesn't compile/run
- Tests are failing (unless deliberate red-phase TDD)
- You're in the middle of a complex change

## Process

### 1. Verify Clean State
**Before committing, ensure:**
- Code compiles/runs
- Tests pass (or it's a deliberate red-phase commit)
- Code is formatted
- No obvious errors or warnings

### 2. Review Changes
- Look at what files changed
- Ensure changes are related and focused
- Check that you're not committing:
  - Secrets or credentials
  - Large binary files accidentally
  - Temporary debug code
  - Commented-out code blocks

### 3. Stage Relevant Files
- Stage files that are part of this logical change
- Don't use `git add .` blindly
- Be intentional about what goes in this commit

### 4. Write Clear Commit Message
**Format:**
```
<action> <what>

Optional: More details if needed
```

**Action verbs (imperative mood):**
- `Add` - New feature/file
- `Implement` - Feature implementation
- `Fix` - Bug fix
- `Refactor` - Code improvement, no behavior change
- `Update` - Modify existing feature
- `Remove` - Delete code/feature
- `Extract` - Pull out code into separate concern
- `Rename` - Change names for clarity

**Examples:**
- `Add validation to user signup`
- `Fix timeout error in API client`
- `Refactor discount calculation to extract tax logic`
- `Update CLAUDE.md with checkpoint philosophy`
- ~~`Update code`~~ (too vague)
- ~~`WIP`~~ (not descriptive)
- ~~`fixes`~~ (not imperative, unclear what was fixed)

### 5. Include Co-Author Attribution
**NEVER include:**
```
Co-Authored-By: Claude <...>
```

**Human work, human credit.** Claude assists, but commits are yours.

### 6. Commit and Verify
- Make the commit
- Verify it was created: `git log -1`
- Check the diff if unsure: `git show`

## Success Criteria

- [ ] Code is in a working state
- [ ] Tests pass (or it's a red-phase commit and marked as such)
- [ ] Code is formatted
- [ ] Changes are focused and related
- [ ] Commit message is clear and descriptive
- [ ] No "Co-Authored-By: Claude" in message
- [ ] You'd be comfortable rolling back to this point

## Language-Specific Implementations

This template is implemented by:
- **Elixir**: `/commit-checkpoint-elixir` - Runs mix format, checks compilation
- **Python**: `/commit-checkpoint-python` - Runs black, checks syntax
- **TypeScript**: `/commit-checkpoint-typescript` - Runs prettier, checks tsc
- **Ruby**: `/commit-checkpoint-ruby` - Runs rubocop basic checks

## Example Usage Patterns

### TDD Cycle
```
1. /tdd-red "calculate user discount"
   -> Commit: "Add failing test for user discount calculation"

2. /implement-<lang>
   -> Commit: "Implement user discount calculation"

3. /refactor-<lang>
   -> Commit: "Refactor discount logic to extract tax calculation"
```

### Incremental Documentation
```
1. Add Communication Style section
   -> /commit-checkpoint "Add Communication Style section to CLAUDE.md"

2. Add TDD Philosophy section
   -> /commit-checkpoint "Add TDD Philosophy section to CLAUDE.md"

3. Add Architecture Principles section
   -> /commit-checkpoint "Add Architecture Principles section to CLAUDE.md"
```

### Bug Fix
```
1. Add test that reproduces bug
   -> /commit-checkpoint "Add test reproducing timeout in API client"

2. Fix the bug
   -> /commit-checkpoint "Fix timeout error by increasing connection timeout"
```

## Common Mistakes

- **Waiting until "done"** - Commit incremental progress
- **Huge commits** - Break into smaller, focused commits
- **Vague messages** - Be specific about what changed
- **Including Claude as co-author** - Human commits only
- **Committing broken code** - Always verify it works first
- **Using `git add .` without checking** - Review what you're staging

## Benefits of Frequent Checkpoints

- **Easy rollback** - Can revert to any checkpoint
- **Clear history** - Each commit tells a story
- **Review-friendly** - Small commits are easier to review
- **Collaboration** - Others can follow your thought process
- **Confidence** - Always have a working state to return to
- **Progress visibility** - See what you accomplished

## The Checkpoint Mindset

**Think:** "Would I want to roll back to this point if something goes wrong?"
- **Yes** -> Commit it
- **No** -> Keep working until you reach a good checkpoint

**Remember:** Commits are cheap, work is expensive. Save often!
