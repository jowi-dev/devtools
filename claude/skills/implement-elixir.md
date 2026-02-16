# TDD Green Phase - Elixir

**Implements:** [tdd-green.md](./tdd-green.md) (language-agnostic template)

## Purpose
Write minimal Elixir code to make the failing test pass.

## Elixir-Specific Process

### 1. Locate/Create Implementation File
**Location:** `lib/` directory

```
test/app/leads_test.exs  →  lib/app/leads.ex
```

### 2. Write Module with Documentation
```elixir
defmodule App.Leads do
  @moduledoc """
  Business logic for lead processing and routing.

  Handles lead scoring, validation, and partner matching.
  """

  @doc """
  Calculates compatibility score between a lead and partner.

  Returns a score between 0.0 and 1.0 based on category matching,
  geographic proximity, and partner capacity.

  ## Examples

      iex> calculate_score(%{category: "auto"}, %{categories: ["auto"]})
      {:ok, 0.85}

  """
  @spec calculate_score(map(), map()) :: {:ok, float()} | {:error, atom()}
  def calculate_score(lead, partner) do
    # Implementation here
  end
end
```

### 3. Implement Minimum to Pass Test

**Start simple:**
```elixir
def calculate_score(lead, partner) do
  if lead.category in partner.categories do
    {:ok, 0.8}
  else
    {:ok, 0.0}
  end
end
```

**That's it!** Don't add features not tested yet.

### 4. Keep Functions SHORT

**🚨 CRITICAL: Bias towards shorter functions**

**Rule of thumb:**
- **5-10 lines**: Good
- **10-15 lines**: Starting to get long, consider extracting
- **15-20 lines**: Definitely extract private functions
- **20+ lines**: Too long, must refactor

**Signs a function is too long:**
- Multiple levels of nesting (`if` inside `case` inside `with`)
- Doing multiple things (validation AND transformation AND business logic)
- Hard to name clearly
- Hard to test specific behaviors

**Extract to private functions:**
```elixir
# Bad - 25 lines, does too much
def process_lead(lead, partner) do
  if lead.email && String.contains?(lead.email, "@") do
    if partner.accepts_category?(lead.category) do
      if partner.capacity > 0 do
        score = calculate_match_score(lead, partner)
        distance = calculate_distance(lead.zip, partner.zip)
        if distance < 50 do
          if score > 0.7 do
            {:ok, %{partner: partner, score: score, distance: distance}}
          else
            {:error, :low_score}
          end
        else
          {:error, :too_far}
        end
      else
        {:error, :no_capacity}
      end
    else
      {:error, :category_mismatch}
    end
  else
    {:error, :invalid_email}
  end
end

# Good - 8 lines, extracts helpers
def process_lead(lead, partner) do
  with :ok <- validate_lead(lead),
       :ok <- validate_partner_match(lead, partner),
       {:ok, score} <- calculate_compatibility(lead, partner) do
    {:ok, %{partner: partner, score: score}}
  end
end

defp validate_lead(%{email: email}) when is_binary(email) do
  if String.contains?(email, "@"), do: :ok, else: {:error, :invalid_email}
end

defp validate_partner_match(lead, partner) do
  cond do
    not partner.accepts_category?(lead.category) -> {:error, :category_mismatch}
    partner.capacity <= 0 -> {:error, :no_capacity}
    true -> :ok
  end
end

defp calculate_compatibility(lead, partner) do
  score = calculate_match_score(lead, partner)
  distance = calculate_distance(lead.zip, partner.zip)

  cond do
    distance >= 50 -> {:error, :too_far}
    score < 0.7 -> {:error, :low_score}
    true -> {:ok, score}
  end
end
```

**Benefits of short functions:**
- ✅ Easier to understand
- ✅ Easier to test specific behaviors
- ✅ Easier to reuse
- ✅ Better error messages (know exactly where it failed)
- ✅ Self-documenting (function names explain intent)

### 5. Follow Elixir Idioms

**Use pattern matching in function heads:**
```elixir
# Good - pattern match for different cases
def calculate_score(%{category: category}, %{categories: categories}) do
  if category in categories, do: {:ok, 0.8}, else: {:ok, 0.0}
end
```

**Use `with` for sequential operations:**
```elixir
def create_user(attrs) do
  with {:ok, validated} <- validate_attrs(attrs),
       {:ok, user} <- insert_user(validated),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, user}
  end
end
```

**Use pipe operator for transformations:**
```elixir
def process_data(data) do
  data
  |> parse_input()
  |> validate()
  |> transform()
  |> save()
end
```

**Use guard clauses:**
```elixir
def calculate_score(lead, partner) when is_map(lead) and is_map(partner) do
  # implementation
end
```

### 6. Add Required Documentation

**Every public function needs:**
- `@doc` - What it does
- `@spec` - Type signature

**Schemas need:**
- `@type t` - Struct type definition

See: `~/Projects/axiom/docs/claude/code-quality.md`

### 7. Run Tests and Quality Checks

```bash
# Run the specific test
MIX_ENV=test mix test test/app/leads_test.exs

# Format code
mix format

# Run full test suite
MIX_ENV=test mix test
```

### 8. Commit the Implementation

```bash
git add lib/app/leads.ex
git commit -m "Implement lead score calculation"
```

## Elixir Patterns

### Return Tuples
```elixir
# Good - consistent error handling
{:ok, result} | {:error, reason}

# Use throughout your API
def create_user(attrs) do
  case Repo.insert(changeset) do
    {:ok, user} -> {:ok, user}
    {:error, changeset} -> {:error, changeset}
  end
end
```

### Use Behaviors for Testability
```elixir
# Define behavior
@callback submit(lead :: map()) :: {:ok, result()} | {:error, term()}

# Inject dependency
def process(lead, engine \\ default_engine()) do
  engine.submit(lead)
end
```

See: `~/Projects/axiom/docs/claude/architecture.md`

### Let It Crash
Don't over-validate internal calls:
```elixir
# Good - trust internal contract
defp calculate_distance(zip1, zip2) do
  # Assumes zips are valid, will crash if not
  # That's OK for internal function
end

# Bad - unnecessary validation
defp calculate_distance(zip1, zip2) do
  if is_binary(zip1) and is_binary(zip2) do
    # ... validation we don't need
  end
end
```

## Success Criteria

- [ ] Test passes
- [ ] All other tests still pass
- [ ] Functions are SHORT (prefer 5-15 lines)
- [ ] Public functions have `@doc` and `@spec`
- [ ] Code follows Elixir idioms
- [ ] Code is formatted (`mix format`)
- [ ] Implementation committed

## Common Mistakes

❌ **Functions too long** - Extract private functions liberally
❌ **Missing @doc/@spec** - Required for all public functions
❌ **Over-engineering** - Don't add untested features
❌ **Unnecessary pipes** - Don't pipe single function calls
❌ **Skipping mix format** - Always format before committing

## Reference

- Code quality: `~/Projects/axiom/docs/claude/code-quality.md`
- Architecture: `~/Projects/axiom/docs/claude/architecture.md`

## Next Steps

After GREEN phase:
1. Look at implementation - is it clean and SHORT?
   - **Yes**: Write next test (`/test-red-elixir`)
   - **No**: Run `/refactor-elixir`
2. If feature complete: Move to next feature
