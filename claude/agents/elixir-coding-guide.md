# Elixir/Phoenix/OTP Coding Standards

Comprehensive reference for Elixir, Phoenix, and OTP development. Consult this agent when working on any Elixir project for architecture, testing, code quality, and workflow guidance.

---

## Architecture

### Domain Structure (DDD / Bounded Contexts)
Organize modules by **domain contexts**:
```
lib/
├── app/                          # Core business logic
│   ├── partner_accounts/         # Context directory
│   │   ├── partner_account.ex    # Schema
│   │   └── queries.ex            # Query helpers
│   └── partner_accounts.ex       # Context API (public interface)
├── app_web/                      # Web layer
│   ├── live/                     # LiveView modules
│   └── controllers/              # Traditional controllers
└── app/repo.ex                   # Database repository
```

Each context encapsulates related functionality and data models. The context module (e.g., `partner_accounts.ex`) is the public interface — external modules call the context, not internal schemas or queries directly.

### Phoenix LiveView Patterns
- LiveView modules handle real-time UI interactions
- Keep business logic in contexts, not LiveViews
- **LiveViews should be thin adapters** that call context functions
- Use `assign/3` and `assign_new/3` for socket state management
- Reference assigns with `@myvar` syntax, never `assigns[:myvar]`

### Design to Behaviors (Critical Principle)

**Design to behaviors, not implementations.**

This prevents tight coupling, enables testing, and makes code reusable.

#### When to Introduce Behaviors
- **Multiple implementations exist or are anticipated**
- **Swapping implementations for testing vs production**
- **External dependencies need abstraction** (APIs, databases, third-party services)
- **Business logic shouldn't couple to infrastructure**

#### How to Design to Behaviors

```elixir
# 1. Define the behavior with @callback
defmodule App.AuctionEngine do
  @callback submit(lead :: map()) :: {:ok, result :: map()} | {:error, reason :: term()}
  @callback fetch_results(auction_id :: String.t()) :: {:ok, results :: map()} | {:error, term()}
end

# 2. Thin wrapper with dependency injection
defmodule App.Leads do
  def submit_to_auction(lead, engine \\ auction_engine()) do
    engine.submit(lead)
  end

  defp auction_engine do
    Application.get_env(:app, :auction_engine, App.AuctionEngine.Boberdoo)
  end
end

# 3. Production implementation
defmodule App.AuctionEngine.Boberdoo do
  @behaviour App.AuctionEngine

  @impl true
  def submit(lead), do: # ... actual HTTP call

  @impl true
  def fetch_results(auction_id), do: # ... actual HTTP call
end

# 4. Test implementation
defmodule App.AuctionEngine.Mock do
  @behaviour App.AuctionEngine

  @impl true
  def submit(_lead), do: {:ok, %{auction_id: "test-123", status: "accepted"}}

  @impl true
  def fetch_results(_id), do: {:ok, %{winner: "partner-1", bid: 10.50}}
end
```

**Key patterns:**
- Use `@behaviour` and `@callback` for formal contracts
- Use protocols for polymorphic behavior across types
- Pass behavior modules as function parameters for flexibility
- Use Application config for swappable implementations

#### When NOT to Use Behaviors
- Simple internal utilities
- Pure functions without external dependencies
- Code that's unlikely to have multiple implementations

**Focus behaviors on:** system boundaries, third-party integrations, complex business logic that varies by context, code that needs different behavior in test vs production.

---

## Testing

### Test Organization
```
test/
├── app/                          # Mirror of lib/app
│   └── partner_accounts_test.exs
├── app_web/                      # Mirror of lib/app_web
│   └── live/
│       └── partner_account_live/
│           └── show_test.exs
└── support/                      # Test helpers
    ├── fixtures/                 # Data factories
    └── conn_case.ex             # Test case templates
```

### Test Patterns
- **One test file per module** — `foo.ex` has `foo_test.exs`
- **Use ExUnit's built-in features** — `describe` blocks, `setup`, etc.
- **Clear test names** — `test "creates partner account with valid attributes"`
- **Arrange-Act-Assert** structure
- **Test edge cases** — Empty inputs, nil values, boundary conditions
- **Test error paths** — Not just happy paths
- **Outside-in test strategy** — Outer layers defined by API endpoints/LiveViews and top level contexts
- **Do not overtest** — Validate what prevents production bugs, nothing more

### LiveView Testing Patterns

**Use Phoenix.LiveViewTest helpers — NEVER parse/slice HTML strings**

```elixir
# GOOD: Use element() and has_element?()
assert has_element?(view, "button[phx-value-step='http_config']")
button_html = view |> element("button[phx-value-step='http_config']") |> render()
assert button_html =~ "active-class"
assert has_element?(view, "[name='test_request[url]']")
refute has_element?(view, "button", "Back")

# BAD: String slicing and regex parsing
html |> String.split("phx-value-step=\"http_config\"") |> Enum.at(1, "")
assert html =~ ~r/phx-click="..."[^>]*class="[^"]*active/
```

LiveView helpers handle attribute order variations, are more reliable when HTML structure changes, and communicate clearer test intent.

### Testing Behaviors

**Test the contract, not the implementation.**

#### Dependency Injection via Function Parameters (best for unit tests)
```elixir
defmodule MockAuctionEngine do
  @behaviour App.AuctionEngine
  def submit(_lead), do: {:ok, %{status: "accepted", id: "test-123"}}
end

test "processes accepted auction result" do
  lead = %{email: "test@example.com"}
  assert {:ok, processed} = MyModule.submit_lead(lead, MockAuctionEngine)
  assert processed.status == "accepted"
end
```

#### Application Config Injection (best for integration tests)
```elixir
# In config/test.exs
config :app, :auction_engine, App.AuctionEngine.Mock
```

#### What to Test
- **Test your business logic**, not the external dependency
- **Test error handling** — Mock error responses from dependencies
- **Test the behavior contract** — Ensure implementations satisfy @callback specs
- **Don't test the mock** — Trust that your mock returns what you told it to

### TDD Workflow
```
1. Write the test first (it will fail)
2. Run: mix test
3. Implement the function
4. Run: mix test (should pass)
5. Add logging (Logger.debug for development ease)
6. Refactor if needed
7. Clean up logger output (capture_log in tests)
8. Commit
```

---

## Code Quality

### Documentation Standards

**ALL public functions MUST have:**
1. **@spec** — Type specification for all parameters and return values
2. **@doc** — Clear description of what the function does

**Every module MUST have:**
- **@moduledoc** describing purpose, responsibility, and how it fits into the system

**All schemas MUST define:**
```elixir
@type t :: %__MODULE__{
  id: integer(),
  name: String.t(),
  # ... other fields
}
```

### Ecto Best Practices

#### Schemas
- Use `@type t :: %__MODULE__{}` for all schemas
- Define clear field types
- Use virtual fields for computed values

#### Changesets
- Validate and cast data through changesets before persistence
- Use appropriate validators: `validate_required/3`, `validate_length/3`, etc.
- Name changesets descriptively: `create_changeset`, `update_changeset`

#### Migrations
- Ecto types and DB types may not match 1:1 (`:varchar`, `:text`, `:bytea` all translate to Ecto's `:string`)
- Not all tables need indexes — use judgment based on query patterns
- Logging tables that are never queried don't need indexes
- Add indexes for foreign keys and frequently queried fields

### Error Handling — "Let It Crash"
- Elixir's core tenet: **let it crash**
- ArgumentError exceptions help identify unexpected conditions
- Don't over-validate internal function calls
- Trust the supervision tree to handle crashes
- Only validate at system boundaries (user input, external APIs)

### Functional Patterns
- Embrace immutability
- Use pipe operator `|>` for data transformation chains
- Pattern match in function heads when possible
- Use `with` for sequential operations that may fail

---

## Anti-Patterns

### Multiple Enum Operations Instead of For Comprehensions
```elixir
# Bad — multiple passes:
list |> Enum.map(&process/1) |> Enum.filter(&valid?/1) |> Enum.map(&transform/1)

# Good — single pass:
for item <- list, processed = process(item), valid?(processed), do: transform(processed)
```
Use `for` when combining map/filter/reject. Use single `Enum` functions for simple one-step transformations.

### Unnecessary Pipe Operator
```elixir
# Bad — pipe with single function:
myvar |> String.to_integer()

# Good — direct call:
String.to_integer(myvar)
```
Use pipes for multi-step transformations, not single function calls.

### Over-qualifying Module Names
```elixir
# Bad:
Kernel.to_string(value)

# Good — auto-imported:
to_string(value)
```

### Unnecessary Destructuring in Function Headers
```elixir
# Bad — destructuring all fields:
def my_func(%MyStruct{this: that, phone: number, name: name}) do ...

# Good — keep headers clean:
def my_func(%MyStruct{} = struct) do
  # Access struct.this, struct.phone, struct.name
end

# Exception — pattern matching for clause selection is fine:
def process_order(%Order{status: :pending} = order), do: handle_pending(order)
def process_order(%Order{status: :completed} = order), do: handle_completed(order)
```

### Nested Case Statements
```elixir
# Bad — deep nesting:
case get_user(id) do
  {:ok, user} ->
    case check_permission(user) do ...

# Good — use with:
with {:ok, user} <- get_user(id),
     {:ok, _} <- check_permission(user),
     {:ok, result} <- update_data(user, data) do
  {:ok, result}
end
```

### Tight Coupling to External Dependencies
```elixir
# Bad — hardcoded:
def submit_lead(lead) do
  HTTPoison.post("https://vendor.com/api/submit", Jason.encode!(lead))
end

# Good — depend on behavior:
def submit_lead(lead, auction_engine \\ default_engine()) do
  auction_engine.submit(lead)
end
```

### Fat LiveViews
Keep business logic in contexts. LiveViews should be thin adapters.

### Over-Abstraction
Don't create behaviors for pure functions or internal utilities that will never have multiple implementations.

---

## Workflow

### Pre-Commit Checklist
1. `mix format` — Format all code
2. `mix compile --warnings-as-errors` — Zero compiler warnings
3. `mix credo --strict` — All Credo checks pass in strict mode
4. `MIX_ENV=test mix test` — All tests pass

**Exception**: Red-phase TDD commits (failing test) may skip the test check. Indicate in commit message (e.g., "Add failing test for...").

### Code Review Checklist

#### Behavior-Driven Design
- [ ] External dependencies abstracted behind behaviors?
- [ ] Multiple/future implementations anticipated?
- [ ] Code testable without external dependencies?
- [ ] Functions accept behavior modules as parameters where appropriate?
- [ ] Application config used for swappable implementations?
- [ ] Behaviors only added where actually needed (not over-abstracted)?

#### Elixir-Specific Quality
- [ ] All public functions have `@spec` and `@doc`
- [ ] Modules have `@moduledoc`
- [ ] Schemas define `@type t`
- [ ] Uses appropriate Ecto patterns (changesets, queries)
- [ ] Follows Elixir idioms (pattern matching, immutability)
- [ ] No unnecessary validations (trust "let it crash")
- [ ] `mix format` / `mix compile --warnings-as-errors` / `mix credo --strict` pass
