# Audit (Language-Agnostic Template)

## Purpose
Run comprehensive quality checks to ensure code meets project standards before committing or pushing.

This is your **pre-flight checklist** - catch issues before they reach code review or production.

## Philosophy

**Trust but verify:**
- You wrote good code
- The tools verify it meets standards
- Fix issues now, not later during review
- Automated checks are fast and consistent

**Quality gates:**
- Formatting (code looks consistent)
- Linting (code follows best practices)
- Type checking (types are correct, if applicable)
- Compilation (code builds successfully)
- Tests (code works as expected)

## When to Use This Skill

**Run audit:**
- ✅ Before committing code
- ✅ After implementing a feature
- ✅ Before creating a pull request
- ✅ After refactoring
- ✅ When you want confidence everything is clean

**Don't skip audit when:**
- ⚠️ Making production changes
- ⚠️ Creating pull requests
- ⚠️ Finishing a feature
- ⚠️ Unsure if everything is working

## Process

### 1. Run Formatter
**Purpose:** Ensure consistent code style

- Run auto-formatter on all changed files
- Formatter should enforce project style guide
- No manual formatting decisions
- Consistent indentation, spacing, line breaks

**Success:** All files pass formatting checks

### 2. Run Linter
**Purpose:** Catch common mistakes and enforce best practices

- Check for code smells
- Find potential bugs
- Enforce language idioms
- Flag unused code
- Suggest improvements

**Success:** No linting errors or warnings (unless explicitly allowed)

### 3. Check Types (if applicable)
**Purpose:** Verify type correctness

- Type-checked languages: Run type checker
- Dynamic languages with types: Run type hint checker
- Ensure type annotations are correct and complete

**Success:** No type errors

### 4. Compile/Build
**Purpose:** Ensure code can be built

- Compiled languages: Run compiler
- Check for syntax errors
- Verify dependencies are available
- Build with warnings as errors (if project requires)

**Success:** Clean compilation, zero warnings

### 5. Run Tests
**Purpose:** Verify behavior is correct

- Run full test suite
- All tests must pass
- Check test coverage (if project requires minimum)
- Verify no tests were accidentally skipped

**Success:** All tests green, expected coverage met

### 6. Report Results
**Summary of:**
- ✅ What passed
- ❌ What failed
- ⚠️ Warnings or concerns
- 📊 Metrics (coverage, complexity, etc.)

## Success Criteria

- [ ] Code is formatted according to project standards
- [ ] No linting errors or warnings
- [ ] Types are correct (if applicable)
- [ ] Code compiles with zero warnings
- [ ] All tests pass
- [ ] Test coverage meets requirements (if applicable)
- [ ] Ready to commit or create PR

## Language-Specific Implementations

This template is implemented by:

- **Elixir**: `/audit-elixir`
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict`
  - `MIX_ENV=test mix test`

- **Python**: `/audit-python`
  - `black --check .`
  - `pylint src/`
  - `mypy src/`
  - `pytest`

- **TypeScript**: `/audit-typescript`
  - `prettier --check .`
  - `eslint .`
  - `tsc --noEmit`
  - `npm test`

- **Ruby**: `/audit-ruby`
  - `rubocop`
  - `bundle exec rspec`

## Example Output

```
🎯 Running audit...

✅ Formatting
   All files formatted correctly

✅ Linting
   0 errors, 0 warnings

✅ Type Checking
   No type errors found

✅ Compilation
   Build successful, 0 warnings

✅ Tests
   42 tests, 42 passed, 0 failed
   Coverage: 94% (meets 90% requirement)

🎉 All checks passed! Ready to commit.
```

## Fixing Issues

### If formatting fails:
```
Run formatter: <language-specific command>
Then re-run audit
```

### If linting fails:
```
Fix each warning/error manually
Or apply auto-fixes if available
Then re-run audit
```

### If compilation fails:
```
Read error messages carefully
Fix syntax/import/type errors
Then re-run audit
```

### If tests fail:
```
Read test failure messages
Fix the bug or update the test
Then re-run audit
```

## Common Mistakes

❌ **Skipping audit** - "I'll run it later" → You forget
❌ **Ignoring warnings** - Warnings become errors eventually
❌ **Committing with failures** - Broken code shouldn't be committed
❌ **Not reading error messages** - They tell you what's wrong
❌ **Auto-fixing without understanding** - Know why it was wrong

## Quality Standards

### Zero tolerance:
- ❌ Syntax errors
- ❌ Type errors
- ❌ Failing tests
- ❌ Compilation warnings (if project requires)

### Fix before committing:
- ⚠️ Linting warnings
- ⚠️ Unused variables/imports
- ⚠️ Low test coverage (if project requires minimum)

### Can be addressed later:
- 📝 Complex refactoring suggestions
- 📝 Performance optimizations
- 📝 Additional test cases

## Integration with Workflow

### TDD Cycle
```
1. /tdd-red → Write test → audit (should fail)
2. /implement → Fix code → audit (should pass)
3. /commit-checkpoint → Commit
```

### Before PR
```
1. Finish all features
2. /audit → Fix any issues
3. Create PR
```

### Continuous Quality
```
Run audit frequently during development
Catch issues early when they're easier to fix
```

## CI/CD Integration

Many projects run these same checks in CI/CD:
- CI runs audit on every push
- PR requires all checks to pass
- Running audit locally saves time
- Catch issues before pushing

## The Quality Loop

```
Write code
    ↓
Run audit
    ↓
Issues? → Fix them → Run audit again
    ↓
All pass? → Commit
```

**Don't skip the audit.** It's faster to fix issues now than during code review.
