---
name: commit-checkpoint-elixir
description: Create checkpoint commits for Elixir development with format/test verification
---

# Commit Checkpoint - Elixir

**Implements:** [commit-checkpoint](../commit-checkpoint) (language-agnostic template)

## Purpose
Create checkpoint commits for incremental Elixir development progress.

## Elixir-Specific Process

### 1. Verify Clean State

```bash
# Ensure code compiles
mix compile

# Ensure tests pass (or it's red phase)
MIX_ENV=test mix test

# Format code
mix format
```

**For red-phase commits:**
Only the failing test should fail, for the right reason.

### 2. Review Changes

```bash
# See what changed
git status

# Review diff
git diff

# Check specific files
git diff lib/app/leads.ex
```

**Don't commit:**
- `mix.lock` changes (unless updating deps intentionally)
- `.elixir_ls/` or `_build/` directories
- Temporary files or debug code
- Secrets in config files

### 3. Stage Files

```bash
# Stage specific files (preferred)
git add lib/app/leads.ex
git add test/app/leads_test.exs

# Or stage all (check git status first!)
git add .
```

**Be intentional** - Know what you're committing

### 4. Write Clear Commit Message

**Format:**
```
<action> <what>

Optional: More details if needed
```

**Elixir-specific examples:**

**TDD commits:**
```bash
# RED phase
git commit -m "Add failing test for lead score calculation"

# GREEN phase
git commit -m "Implement lead score calculation"

# REFACTOR
git commit -m "Extract score calculation into private functions"
git commit -m "Refactor process_lead to reduce function length"
```

**Feature commits:**
```bash
git commit -m "Add email validation to user signup"
git commit -m "Implement partner matching algorithm"
git commit -m "Add behavior for external API clients"
```

**Bug fix commits:**
```bash
git commit -m "Fix timeout error in auction API client"
git commit -m "Fix race condition in lead processing"
```

**Documentation commits:**
```bash
git commit -m "Add @doc and @spec to Leads module"
git commit -m "Update CLAUDE.md with behavior-driven design section"
```

**Refactoring commits:**
```bash
git commit -m "Extract validation logic from create_user"
git commit -m "Split LeadRouter into smaller modules"
git commit -m "Replace nested case with with statement"
```

### 5. NO Co-Authored-By: Claude

**NEVER include:**
```
Co-Authored-By: Claude <...>
```

Human work, human credit.

### 6. Commit and Verify

```bash
# Make the commit
git commit -m "Implement lead score calculation"

# Verify
git log -1

# Check what was committed
git show
```

## Elixir TDD Workflow with Checkpoints

### Complete Feature Cycle

```bash
# 1. RED - Write failing test
/test-red-elixir "calculate lead score"
MIX_ENV=test mix test test/app/leads_test.exs  # Fails (good!)
git add test/app/leads_test.exs
git commit -m "Add failing test for lead score calculation"

# 2. GREEN - Implement feature
# ... write code in lib/app/leads.ex ...
mix format
MIX_ENV=test mix test  # Passes (good!)
git add lib/app/leads.ex
git commit -m "Implement lead score calculation"

# 3. REFACTOR - Clean up (if needed)
# ... extract long functions ...
mix format
MIX_ENV=test mix test  # Still passes
git add lib/app/leads.ex
git commit -m "Extract score calculation helpers"

# 4. Add edge case test
/test-red-elixir "score calculation with missing data"
MIX_ENV=test mix test  # New test fails
git commit -m "Add test for score calculation with missing data"

# 5. Handle edge case
# ... update implementation ...
mix format
MIX_ENV=test mix test  # All pass
git commit -m "Handle missing data in score calculation"
```

Each commit is a checkpoint!

## When to Commit (Elixir-Specific)

### Commit after:
- Added one test (`_test.exs` file)
- Implemented one function
- Refactored one function
- Added documentation to one module
- Fixed one bug
- Added one migration
- Updated one schema
- Extracted one behavior
- Added one config change

### Example commit sizes:

**Good - focused commits:**
```
"Add failing test for user validation"
   - 1 file: test/app/accounts_test.exs
   - ~20 lines

"Implement user validation"
   - 1 file: lib/app/accounts.ex
   - ~30 lines

"Extract email validation to private function"
   - 1 file: lib/app/accounts.ex
   - ~15 lines changed
```

**Bad - too large:**
```
"Implement user management"
   - 8 files changed
   - 500+ lines
   - Mixed concerns (validation, auth, emails, tests)
```

## Quality Standards Before Committing

### Always check:
```bash
mix format
mix compile
MIX_ENV=test mix test  # Unless red-phase
```

### For important commits (before PR):
```bash
mix format --check-formatted && \
mix compile --warnings-as-errors && \
mix credo --strict && \
MIX_ENV=test mix test
```

## Common Elixir Commit Patterns

### Schema changes:
```bash
# 1. Migration
git add priv/repo/migrations/*_add_category_to_leads.exs
git commit -m "Add migration for category field on leads"

# 2. Schema update
git add lib/app/leads/lead.ex
git commit -m "Add category field to Lead schema"

# 3. Update tests
git add test/app/leads/lead_test.exs
git commit -m "Update Lead tests for category field"
```

### Behavior implementation:
```bash
# 1. Define behavior
git add lib/app/auction_engine.ex
git commit -m "Define AuctionEngine behavior"

# 2. Implement for production
git add lib/app/auction_engine/boberdoo.ex
git commit -m "Implement AuctionEngine.Boberdoo"

# 3. Implement for tests
git add test/support/auction_engine_mock.ex
git commit -m "Add AuctionEngine.Mock for testing"

# 4. Update context to use behavior
git add lib/app/leads.ex
git commit -m "Update Leads to use AuctionEngine behavior"
```

### Documentation:
```bash
# Per module
git add lib/app/leads.ex
git commit -m "Add @doc and @spec to Leads public functions"

git add lib/app/partners.ex
git commit -m "Add @moduledoc to Partners context"
```

## Success Criteria

- [ ] Code compiles (`mix compile`)
- [ ] Tests pass (or it's red-phase and marked)
- [ ] Code is formatted (`mix format`)
- [ ] Changes are focused and related
- [ ] Commit message is clear and specific
- [ ] NO "Co-Authored-By: Claude"
- [ ] You'd be comfortable rolling back to this point

## Common Mistakes

- **Committing mix.lock unintentionally**
- **Huge commits** - Break into smaller pieces
- **Vague messages** - "Update code" -> What code? Why?
- **Skipping mix format**
- **Committing failing tests** (unless red-phase)
- **Including Claude co-author**

## Checkpoint Philosophy Applied

Remember:
- **Bonfire** - Rest at each safe spot
- **Save point** - Capture working state often
- **Snapshot** - Each commit tells a story
- **Checkpoint** - Don't wait for "done"

**Commits are cheap, work is expensive. Save often!**

## Reference

- Workflow: `~/Projects/axiom/docs/claude/workflow.md`
- Global commit philosophy: `~/devtools/claude/CLAUDE.md`

## Next Steps

After committing:
1. **Continue TDD cycle** - Back to `/test-red-elixir` for next behavior
2. **Feature complete?** - Run `/audit-elixir` for final check
3. **Ready for PR?** - Create pull request
