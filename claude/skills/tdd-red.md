# TDD Red Phase (Language-Agnostic Template)

## Purpose
Write a failing test that describes the desired behavior of a feature that doesn't exist yet.

This is the **RED** phase of Test-Driven Development: create a test that fails for the right reason.

## Process

### 1. Understand the Requirement
- What behavior are we adding?
- What inputs and outputs are expected?
- What edge cases need handling?

### 2. Create Test File
- Follow project's test file naming conventions
- Mirror the source file structure in test directory
- Use project's test framework setup

### 3. Write Minimal Failing Test
- Name the test clearly: describe what it tests
- Use Arrange-Act-Assert pattern:
  - **Arrange**: Set up test data
  - **Act**: Call the function/method being tested
  - **Assert**: Verify the expected behavior
- Test ONE specific behavior
- Keep it simple - don't test everything at once

### 4. Run the Test
- Execute project's test command
- Verify the test FAILS
- Read the failure message carefully

### 5. Verify Failure Reason
**Critical**: The test should fail because the feature doesn't exist, NOT because:
- Syntax errors in the test
- Import/module errors
- Typos in function names
- Test framework issues

If it fails for the wrong reason, fix the test first.

### 6. Commit the Failing Test
- Commit message: `"Add failing test for <feature>"`
- This is a valid TDD commit (red phase)
- The codebase is in a known state: "feature not yet implemented"

## Success Criteria

- [ ] Test file created in correct location
- [ ] Test clearly describes desired behavior
- [ ] Test follows project's testing patterns
- [ ] Test fails with clear, expected failure message
- [ ] Failure is because feature doesn't exist (not a test bug)
- [ ] Test is committed with descriptive message

## Language-Specific Implementations

This template is implemented by:
- **Elixir**: `/test-red-elixir` - Uses ExUnit, test/ directory, `_test.exs` files
- **Python**: `/test-red-python` - Uses pytest, tests/ directory, `test_*.py` files
- **TypeScript**: `/test-red-typescript` - Uses Jest/Vitest, `__tests__/` or `*.test.ts` files
- **Ruby**: `/test-red-ruby` - Uses RSpec/Minitest, spec/ or test/ directory

## Example (Conceptual)

```
# Test: Calculate discount for premium users
test "calculates 20% discount for premium users":
  user = create_premium_user()
  product = create_product(price: 100)

  result = calculate_discount(user, product)

  assert result == 20
```

**This test will fail** because `calculate_discount` doesn't exist yet. That's perfect - that's the RED phase.

## Common Mistakes

❌ **Testing implementation details** - Test behavior, not how it's implemented
❌ **Testing multiple things** - One test, one behavior
❌ **Complex test setup** - Keep test data simple
❌ **Vague test names** - Name should describe the specific behavior
❌ **Not running the test** - Always verify it fails first

## What's Next

After completing RED phase:
1. Run `/implement` (GREEN phase) - Write minimal code to make test pass
2. Run tests again - Verify they now pass
3. Run `/refactor` if needed - Clean up while keeping tests green
