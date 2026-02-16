# Audit - Elixir

**Implements:** [audit.md](./audit.md) (language-agnostic template)

## Purpose
Run comprehensive quality checks for Elixir/Phoenix projects.

## Elixir Quality Checks

### 1. Format Check
```bash
mix format --check-formatted
```

**Purpose:** Ensure code follows project formatting standards

**If fails:**
```bash
mix format
# Then re-run audit
```

### 2. Compilation Check
```bash
mix compile --warnings-as-errors
```

**Purpose:** Ensure code compiles with zero warnings

**Common warnings:**
- Unused variables (prefix with `_` if intentional)
- Unused imports
- Undefined functions
- Type mismatches

**If fails:** Fix each warning, then re-run

### 3. Credo (Linter)
```bash
mix credo --strict
```

**Purpose:** Check code quality and consistency

**What it checks:**
- Code readability
- Refactoring opportunities
- Software design suggestions
- Common mistakes
- Consistency issues

**Categories:**
- **Consistency** - Code style consistency
- **Design** - Design suggestions (long functions, complex modules)
- **Readability** - Code clarity issues
- **Refactor** - Refactoring opportunities
- **Warning** - Potential problems

**If fails:** Review each issue, fix or explicitly allow

### 4. Test Suite
```bash
MIX_ENV=test mix test
```

**Purpose:** Verify all behavior is correct

**What it checks:**
- All tests pass
- No skipped tests (unless intentional)
- Tests run without errors

**If fails:**
- Read test failure messages
- Fix the bug or update the test
- Re-run audit

## Complete Audit Command

Run all checks in sequence:

```bash
# Full audit
mix format --check-formatted && \
mix compile --warnings-as-errors && \
mix credo --strict && \
MIX_ENV=test mix test
```

Or create a mix task:

```elixir
# lib/mix/tasks/audit.ex
defmodule Mix.Tasks.Audit do
  use Mix.Task

  @shortdoc "Run full quality audit"
  def run(_) do
    Mix.Task.run("format", ["--check-formatted"])
    Mix.Task.run("compile", ["--warnings-as-errors"])
    Mix.Task.run("credo", ["--strict"])
    Mix.Task.run("test")
  end
end
```

Then: `mix audit`

## Expected Output

### ✅ All Passing
```
🎯 Running Elixir audit...

✅ Formatting
   All files formatted correctly

✅ Compilation
   Build successful, 0 warnings

✅ Credo
   0 issues found (strict mode)

✅ Tests
   124 tests, 124 passed, 0 failed
   Test time: 3.2 seconds

🎉 All checks passed! Ready to commit.
```

### ❌ With Issues
```
🎯 Running Elixir audit...

✅ Formatting
   All files formatted correctly

❌ Compilation
   warning: variable "user" is unused
     lib/app/leads.ex:42

❌ Credo
   [D] ↗ Function body is too long (max is 20, was 35).
       lib/app/leads/router.ex:15

✅ Tests
   124 tests, 124 passed, 0 failed

❌ Audit failed. Fix issues above.
```

## Fixing Common Issues

### Compilation Warnings

**Unused variable:**
```elixir
# Bad
def process(user, data) do
  # not using user
  transform(data)
end

# Good - prefix with underscore
def process(_user, data) do
  transform(data)
end
```

**Unused import:**
```elixir
# Bad
import Ecto.Query  # but not using it

# Good - remove it
# (or use alias instead if needed for types)
```

### Credo Issues

**Function too long (>20 lines):**
```elixir
# Fix: Extract private functions
# See: /refactor-elixir skill
```

**Complex function (cyclomatic complexity >10):**
```elixir
# Fix: Simplify logic, extract functions
# Use pattern matching instead of nested if/case
```

**Module too long:**
```elixir
# Fix: Split into multiple modules
# Each module should have single responsibility
```

**Inconsistent alias/import order:**
```elixir
# Fix: Let mix format handle it
mix format
```

### Test Failures

**Assertion failed:**
```
1) test calculates correct score (App.LeadsTest)
   test/app/leads_test.exs:42
   Assertion with == failed
   code:  assert score == 0.8
   left:  0.75
   right: 0.8
```

**Fix:** Either fix the implementation or update the test expectation

**Database error:**
```
** (Postgrex.Error) ERROR: column "category" does not exist
```

**Fix:** Run migrations or update test data

## Integration with Workflow

### Before Committing
```bash
# Always run audit before commit
mix audit  # or the full command

# If passes → commit
git add .
git commit -m "..."

# If fails → fix issues, then commit
```

### TDD Cycle with Audit
```bash
# 1. RED phase
/test-red-elixir "feature"
MIX_ENV=test mix test test/path/to/test.exs  # Should fail

# 2. GREEN phase
/implement-elixir
mix test  # Should pass
mix format  # Format before audit

# 3. Audit
mix audit  # All checks should pass

# 4. Commit
git commit -m "Implement feature"

# 5. REFACTOR (if needed)
/refactor-elixir
mix test  # Still passes
mix audit  # Still passes
git commit -m "Refactor ..."
```

### Before PR
```bash
# Final audit before creating PR
mix audit

# If fails → fix everything
# If passes → create PR
```

## Axiom-Specific Checks

Based on `~/Projects/axiom/docs/claude/`:

### Documentation Standards
- [ ] All public functions have `@doc`
- [ ] All public functions have `@spec`
- [ ] All modules have `@moduledoc`
- [ ] All schemas have `@type t`

### Code Quality
- [ ] No functions >20 lines
- [ ] Most functions 5-15 lines
- [ ] No unnecessary pipes (single function calls)
- [ ] No over-qualification of Kernel functions
- [ ] Pattern matching used appropriately
- [ ] `with` used for sequential operations

### Architecture
- [ ] External dependencies behind behaviors
- [ ] Business logic in contexts, not web layer
- [ ] LiveViews are thin (call context functions)

See:
- Code quality: `~/Projects/axiom/docs/claude/code-quality.md`
- Architecture: `~/Projects/axiom/docs/claude/architecture.md`
- Testing: `~/Projects/axiom/docs/claude/testing.md`

## Success Criteria

- [ ] `mix format --check-formatted` passes
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix credo --strict` passes
- [ ] `MIX_ENV=test mix test` passes
- [ ] All quality standards met
- [ ] Ready to commit or create PR

## Common Mistakes

❌ **Skipping audit** - "I'll fix it later"
❌ **Ignoring credo warnings** - "It's just a suggestion"
❌ **Committing with warnings** - "It compiles though"
❌ **Not running tests** - "I only changed docs"
❌ **Skipping format** - "I'll let CI do it"

## CI/CD Note

Many projects run these same checks in CI:
- GitHub Actions runs audit on every push
- PR requires all checks to pass
- Running audit locally saves time
- Catch issues before pushing

## Quick Reference

```bash
# Individual checks
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
MIX_ENV=test mix test

# All at once
mix format --check-formatted && \
mix compile --warnings-as-errors && \
mix credo --strict && \
MIX_ENV=test mix test

# Auto-fix what you can
mix format
# Then re-run audit
```

## Next Steps

**All checks pass?**
- ✅ Commit your changes
- ✅ Create PR if ready
- ✅ Move to next feature

**Checks fail?**
- ❌ Fix issues one by one
- ❌ Re-run audit after each fix
- ❌ Don't commit until green
