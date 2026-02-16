# TDD Refactor Phase (Language-Agnostic Template)

## Purpose
Improve code quality without changing behavior, while keeping all tests green.

This is the **REFACTOR** phase of Test-Driven Development: clean up the code while maintaining passing tests.

## When to Refactor

**Do refactor when you see:**
- Duplicated code
- Long, complex functions
- Unclear variable/function names
- Poor structure or organization
- Code that's hard to understand
- Violations of language idioms

**Don't refactor when:**
- Tests are red (fix them first)
- You're not sure what the code does
- You're adding new features (write tests first)
- Code is already clean and simple

## Process

### 1. Ensure Green State
**CRITICAL: All tests must pass before refactoring.**

- Run full test suite
- Verify everything is green
- If anything is red, fix it first or revert changes

### 2. Identify What to Improve
Look for code smells:
- Duplicated logic
- Long functions (>20 lines is a smell)
- Deep nesting (>3 levels)
- Magic numbers or strings
- Unclear names
- Mixed concerns (doing too many things)

### 3. Make One Small Change
**Refactor in tiny steps:**
- Extract a function
- Rename a variable
- Remove duplication
- Simplify conditional logic
- Reorganize code structure

**One change at a time** - Don't refactor everything at once.

### 4. Run Tests After Each Change
- Run test suite after EVERY small change
- Tests should stay green
- If tests fail:
  - **Stop immediately**
  - **Revert the change**
  - **Try a smaller change**

### 5. Run Quality Checks
- Format code
- Check linting
- Verify compilation
- Fix any warnings

### 6. Commit the Refactor
- Commit message: `"Refactor <what-you-changed>"`
- Example: `"Refactor calculate_discount to extract tax logic"`
- Commit after each logical refactoring step

## Success Criteria

- [ ] All tests still pass (nothing broke)
- [ ] Code is cleaner/clearer than before
- [ ] No behavior changes (tests prove this)
- [ ] Code is formatted and linted
- [ ] Refactor is committed with descriptive message

## Language-Specific Implementations

This template is implemented by:
- **Elixir**: `/refactor-elixir` - Uses mix format/test, follows Elixir idioms
- **Python**: `/refactor-python` - Uses black/pytest, follows PEP 8
- **TypeScript**: `/refactor-typescript` - Uses prettier/jest, follows TS patterns
- **Ruby**: `/refactor-ruby` - Uses rubocop/rspec, follows Ruby style

## Example Refactoring

**Before (works but smelly):**
```
def process_order(order):
  if order.user.is_premium and order.user.subscription.active:
    discount = order.total * 0.20
  else:
    discount = 0

  tax = order.total * 0.08
  shipping = calculate_shipping(order)

  return order.total - discount + tax + shipping
```

**After (cleaner):**
```
def process_order(order):
  subtotal = order.total
  discount = calculate_discount(order)
  tax = calculate_tax(order)
  shipping = calculate_shipping(order)

  return subtotal - discount + tax + shipping

def calculate_discount(order):
  if is_eligible_for_discount(order.user):
    return order.total * 0.20
  return 0

def is_eligible_for_discount(user):
  return user.is_premium and user.subscription.active

def calculate_tax(order):
  return order.total * 0.08
```

**Tests still pass!** Behavior unchanged, but code is much clearer.

## Common Refactorings

### Extract Function
- When: Function does too much, or has duplicated code
- How: Pull out a chunk into a new function with clear name

### Rename
- When: Variable/function name is unclear
- How: Use IDE refactoring or find-replace carefully

### Simplify Conditional
- When: Complex if/else chains
- How: Extract conditions to well-named functions

### Remove Duplication
- When: Same logic appears multiple times
- How: Extract to shared function

### Split Function
- When: Function is too long or does multiple things
- How: Break into smaller, focused functions

## Common Mistakes

❌ **Refactoring while tests are red** - Always start with green
❌ **Making multiple changes at once** - Small steps, test after each
❌ **Changing behavior** - Refactor means same behavior, better code
❌ **Over-engineering** - Keep it simple, don't add complexity
❌ **Not committing frequently** - Commit after each logical refactor

## The Golden Rule

**If tests go red during refactoring, you made a mistake. Revert immediately.**

Refactoring should be safe and boring. Tests are your safety net.

## What's Next

After refactoring:
1. **More refactoring needed?** Continue with small steps
2. **Code is clean?** Back to `/tdd-red` for next feature
3. **Feature complete?** Move to next feature or task

## Red-Green-Refactor Cycle

```
RED    → Write failing test
GREEN  → Make it pass (simple/ugly is OK)
REFACTOR → Clean it up (keep tests green)
↓
Repeat
```

This skill completes the cycle before starting the next test.
