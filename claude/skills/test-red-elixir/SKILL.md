---
name: test-red-elixir
description: Write failing ExUnit test for Elixir (TDD RED phase)
---

# TDD Red Phase - Elixir

**Implements:** [tdd-red](../tdd-red) (language-agnostic template)

## Purpose
Write a failing ExUnit test that describes desired Elixir behavior.

## Elixir-Specific Process

### 1. Create Test File
**Location:** `test/` directory, mirroring `lib/` structure

```
lib/app/leads.ex          ->  test/app/leads_test.exs
lib/app_web/live/foo.ex   ->  test/app_web/live/foo_test.exs
```

**Naming:** `<module_name>_test.exs`

### 2. Set Up Test Module
```elixir
defmodule App.LeadsTest do
  use App.DataCase          # For tests that use the database
  # or
  use ExUnit.Case           # For tests without database

  alias App.Leads

  describe "calculate_score/2" do
    # tests go here
  end
end
```

### 3. Write Test Using ExUnit
**Pattern: Arrange-Act-Assert**

```elixir
test "calculates high score for matching categories" do
  # Arrange - Set up test data
  lead = %{category: "auto", email: "test@example.com"}
  partner = %{categories: ["auto", "insurance"]}

  # Act - Call the function
  result = Leads.calculate_score(lead, partner)

  # Assert - Verify behavior
  assert {:ok, score} = result
  assert score >= 0.8
end
```

**Test naming:**
- Descriptive: `test "creates user with valid attributes"`
- Present tense: `"returns error for invalid email"`
- Specific: `"calculates 20% discount for premium users"`

### 4. Run the Test
```bash
# Run specific test file
MIX_ENV=test mix test test/app/leads_test.exs

# Run specific test by line number
MIX_ENV=test mix test test/app/leads_test.exs:42

# Run all tests
MIX_ENV=test mix test
```

### 5. Verify Failure Reason
**Should see:** `** (UndefinedFunctionError) function App.Leads.calculate_score/2 is undefined`

**Should NOT see:**
- Compilation errors
- Syntax errors in test
- Module not found (wrong alias)
- Setup/fixture errors

### 6. Commit the Failing Test
```bash
git add test/app/leads_test.exs
git commit -m "Add failing test for lead score calculation"
```

## ExUnit Patterns

### Use describe Blocks
Group related tests:
```elixir
describe "calculate_score/2" do
  test "returns high score for matching category"
  test "returns low score for non-matching category"
  test "returns error for invalid input"
end
```

### Use setup for Test Data
```elixir
describe "with premium user" do
  setup do
    user = create_premium_user()
    product = create_product(price: 100)
    %{user: user, product: product}
  end

  test "applies discount", %{user: user, product: product} do
    assert {:ok, discount} = calculate_discount(user, product)
  end
end
```

### Test Fixtures
Use fixtures from `test/support/fixtures/`:
```elixir
import App.AccountsFixtures

test "creates valid user" do
  user = user_fixture()  # from fixtures
  assert user.email
end
```

### Pattern Match Assertions
```elixir
# Good - Pattern match in assertion
assert {:ok, %User{email: email}} = Accounts.create_user(attrs)
assert email == "test@example.com"

# Also good - Separate assert
assert {:ok, user} = Accounts.create_user(attrs)
assert user.email == "test@example.com"
```

### Test Error Cases
```elixir
test "returns error for duplicate email" do
  user_fixture(email: "test@example.com")

  assert {:error, changeset} = Accounts.create_user(%{email: "test@example.com"})
  assert "has already been taken" in errors_on(changeset).email
end
```

## Elixir-Specific Anti-Patterns

**Don't destructure everything in test setup**
```elixir
# Bad
test "does something", %{user: %User{id: id, name: name, email: email}} do
```

**Keep it simple**
```elixir
# Good
test "does something", %{user: user} do
  # Use user.id, user.name when needed
```

**Don't use pipes in tests unnecessarily**
```elixir
# Bad - confusing
result = attrs |> Accounts.create_user() |> elem(1)

# Good - clear
{:ok, user} = Accounts.create_user(attrs)
```

**Don't test implementation details**
```elixir
# Bad - tests how it works
test "calls Repo.insert with changeset" do
  # ...
end

# Good - tests what it does
test "creates user with valid attributes" do
  # ...
end
```

## Success Criteria

- [ ] Test file in `test/` mirroring `lib/` structure
- [ ] Test module uses `App.DataCase` or `ExUnit.Case`
- [ ] Tests grouped in `describe` blocks
- [ ] Test names are descriptive and specific
- [ ] Arrange-Act-Assert pattern clear
- [ ] Test fails because function doesn't exist
- [ ] Committed with message: `"Add failing test for <feature>"`

## Reference

See full testing guidelines: `~/Projects/axiom/docs/claude/testing.md`

## Next Steps

After RED phase:
1. Run `/implement-elixir` to write the implementation
2. Verify test passes
3. Refactor if needed with `/refactor-elixir`
