# TDD Refactor Phase - Elixir

**Implements:** [tdd-refactor.md](./tdd-refactor.md) (language-agnostic template)

## Purpose
Improve Elixir code quality while keeping all tests green.

## Critical Rule

**🚨 ALL TESTS MUST BE GREEN BEFORE REFACTORING**

Run `MIX_ENV=test mix test` first. If anything fails, fix it or revert.

## Elixir-Specific Refactorings

### 1. Extract Long Functions (PRIORITY #1)

**This is the most common refactoring needed in axiom codebase.**

**Check every function:**
- **>15 lines**: Extract private functions NOW
- **10-15 lines**: Consider extracting if doing multiple things
- **<10 lines**: Probably fine

**How to extract:**

```elixir
# Before - 28 lines, too long
def process_lead(lead_attrs, partner_id) do
  changeset = Lead.changeset(%Lead{}, lead_attrs)

  if changeset.valid? do
    lead = Repo.insert!(changeset)

    partner = Repo.get!(Partner, partner_id)

    if partner.active && partner.capacity > 0 do
      category_match = lead.category in partner.categories
      distance = calculate_geo_distance(lead.zip, partner.zip)

      if category_match && distance < 50 do
        score = (category_weight * 0.6) + (distance_weight * 0.4)

        if score > 0.7 do
          Repo.insert!(%Match{
            lead_id: lead.id,
            partner_id: partner.id,
            score: score
          })

          {:ok, "matched"}
        else
          {:error, "low_score"}
        end
      else
        {:error, "no_match"}
      end
    else
      {:error, "partner_unavailable"}
    end
  else
    {:error, changeset}
  end
end

# After - 8 lines per function, much clearer
def process_lead(lead_attrs, partner_id) do
  with {:ok, lead} <- create_lead(lead_attrs),
       {:ok, partner} <- fetch_active_partner(partner_id),
       {:ok, score} <- calculate_match(lead, partner),
       {:ok, match} <- create_match(lead, partner, score) do
    {:ok, "matched"}
  end
end

defp create_lead(attrs) do
  %Lead{}
  |> Lead.changeset(attrs)
  |> Repo.insert()
end

defp fetch_active_partner(partner_id) do
  case Repo.get(Partner, partner_id) do
    %Partner{active: true, capacity: cap} = partner when cap > 0 ->
      {:ok, partner}

    %Partner{} ->
      {:error, "partner_unavailable"}

    nil ->
      {:error, "partner_not_found"}
  end
end

defp calculate_match(lead, partner) do
  category_match? = lead.category in partner.categories
  distance = calculate_geo_distance(lead.zip, partner.zip)

  cond do
    not category_match? -> {:error, "no_match"}
    distance >= 50 -> {:error, "no_match"}
    true -> {:ok, calculate_score(lead, partner, distance)}
  end
end

defp calculate_score(lead, partner, distance) do
  category_weight = if lead.category in partner.categories, do: 1.0, else: 0.0
  distance_weight = max(0.0, 1.0 - distance / 50.0)
  score = (category_weight * 0.6) + (distance_weight * 0.4)

  if score > 0.7, do: {:ok, score}, else: {:error, "low_score"}
end

defp create_match(lead, partner, score) do
  %Match{}
  |> Match.changeset(%{
    lead_id: lead.id,
    partner_id: partner.id,
    score: score
  })
  |> Repo.insert()
end
```

**Benefits:**
- Each function does ONE thing
- Easy to test each piece independently
- Clear names document intent
- Easy to reuse logic
- Stack traces show exactly where error occurred

### 2. Use `with` for Sequential Operations

**Before - nested case:**
```elixir
def create_user(attrs) do
  case validate_email(attrs.email) do
    {:ok, email} ->
      case create_account(email) do
        {:ok, account} ->
          case send_welcome(account) do
            {:ok, _} -> {:ok, account}
            error -> error
          end
        error -> error
      end
    error -> error
  end
end
```

**After - `with`:**
```elixir
def create_user(attrs) do
  with {:ok, email} <- validate_email(attrs.email),
       {:ok, account} <- create_account(email),
       {:ok, _} <- send_welcome(account) do
    {:ok, account}
  end
end
```

### 3. Extract Magic Numbers

**Before:**
```elixir
def calculate_discount(user, order) do
  if user.premium && order.total > 100 do
    order.total * 0.15
  else
    0
  end
end
```

**After:**
```elixir
@premium_threshold 100
@premium_discount_rate 0.15

def calculate_discount(user, order) do
  if qualifies_for_discount?(user, order) do
    order.total * @premium_discount_rate
  else
    0
  end
end

defp qualifies_for_discount?(user, order) do
  user.premium && order.total > @premium_threshold
end
```

### 4. Simplify Pattern Matching

**Before - unnecessary destructuring:**
```elixir
def process_user(%User{id: id, email: email, name: name, role: role}) do
  # uses id, email, name, role
end
```

**After - keep it simple:**
```elixir
def process_user(%User{} = user) do
  # use user.id, user.email, user.name, user.role
end
```

**Exception - pattern match for clause selection:**
```elixir
# This IS appropriate
def process_order(%Order{status: :pending} = order), do: handle_pending(order)
def process_order(%Order{status: :complete} = order), do: handle_complete(order)
```

### 5. Use `for` Comprehensions

**Before - multiple Enum operations:**
```elixir
leads
|> Enum.map(&transform/1)
|> Enum.filter(&valid?/1)
|> Enum.map(&enrich/1)
```

**After - single pass:**
```elixir
for lead <- leads,
    transformed = transform(lead),
    valid?(transformed) do
  enrich(transformed)
end
```

See: `~/Projects/axiom/docs/claude/code-quality.md`

### 6. Remove Unnecessary Pipes

**Before:**
```elixir
result |> IO.inspect()
myvar |> String.to_integer()
```

**After:**
```elixir
IO.inspect(result)
String.to_integer(myvar)
```

**Keep pipes for multi-step transformations:**
```elixir
# Good use of pipes
data
|> parse_input()
|> validate()
|> transform()
|> save()
```

## Refactoring Process

### 1. Ensure Green
```bash
MIX_ENV=test mix test
```

All tests must pass.

### 2. Make ONE Small Change
- Extract one private function
- Rename one variable
- Simplify one conditional
- Extract one constant

**One change at a time!**

### 3. Run Tests After Each Change
```bash
MIX_ENV=test mix test
```

**Tests go red?** → Revert immediately → Try smaller change

### 4. Format Code
```bash
mix format
```

### 5. Commit the Refactor
```bash
git add lib/app/leads.ex
git commit -m "Refactor process_lead to extract validation logic"
```

Commit after each logical refactoring step.

## Common Elixir Refactorings

### Extract Private Function
```elixir
# When: Function >15 lines or doing multiple things
# How: Pull logic into well-named private function

def long_function do
  # part 1
  # part 2
  # part 3
end

# Becomes:
def long_function do
  step_1()
  step_2()
  step_3()
end

defp step_1, do: # ...
defp step_2, do: # ...
defp step_3, do: # ...
```

### Introduce Function Clause
```elixir
# When: Complex if/case for different inputs
# How: Pattern match in function head

def process(data) do
  if is_map(data), do: process_map(data), else: process_list(data)
end

# Becomes:
def process(data) when is_map(data), do: process_map(data)
def process(data) when is_list(data), do: process_list(data)
```

### Replace Nested with Guard
```elixir
# When: Nested if checks
# How: Guard clause + early return

def calculate(x, y) do
  if x > 0 do
    if y > 0 do
      x * y
    else
      0
    end
  else
    0
  end
end

# Becomes:
def calculate(x, y) when x > 0 and y > 0, do: x * y
def calculate(_x, _y), do: 0
```

## Success Criteria

- [ ] All tests still pass
- [ ] Functions are SHORT (5-15 lines)
- [ ] Code is cleaner than before
- [ ] No behavior changes (tests prove this)
- [ ] Code is formatted
- [ ] Refactor committed with clear message

## Common Mistakes

❌ **Refactoring while tests are red**
❌ **Multiple changes at once**
❌ **Changing behavior**
❌ **Making code more complex**
❌ **Not committing frequently**

## Function Length Checklist

After refactoring, check EVERY function:
- [ ] No function >20 lines (hard limit)
- [ ] Most functions 5-15 lines
- [ ] Each function does ONE thing
- [ ] Function names clearly describe what they do
- [ ] Easy to test each function independently

## Reference

- Anti-patterns: `~/Projects/axiom/docs/claude/code-quality.md`
- Architecture: `~/Projects/axiom/docs/claude/architecture.md`

## Next Steps

After refactoring:
1. **More refactoring needed?** Continue with small steps
2. **Code is clean and SHORT?** Back to `/test-red-elixir`
3. **Feature complete?** Move to next feature
