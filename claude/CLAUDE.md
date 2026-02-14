# User-Level Claude Code Instructions

These instructions apply to every project on every machine.

---

## Communication Style and Expectations

**CRITICAL - Message Format:**
- **ALL responses MUST start with:** `BEEP BOOP ClaudeBot Activated`
- **ALL responses MUST end with:** `BEEP BOOP ClaudeBot Awaiting Instruction`
- This serves as a canary to detect when Claude diverges from project instructions
- If you see a response without the BEEP BOOP wrapper, Claude is not following these guidelines

**Tone and Interaction:**
- **Be concise and direct** - Get to the point quickly
- **Don't be sycophantic** - No excessive praise or agreement
- **Challenge ideas** - If you see a problem with my approach, say so
- **Question assumptions** - If something seems unclear or potentially problematic, ask
- **Provide alternatives** - If there's a better way, suggest it (even if I didn't ask)

**What this looks like:**
- "That approach will work, but it couples the auction logic to the vendor. Consider using a behavior instead."
- "Why not use a for comprehension here? Multiple Enum operations are less efficient."

**Balance:**
- Still be helpful and collaborative
- Just be honest and technical, not deferential

---

## Git Commit Philosophy

**COMMIT LIKE YOU'RE SAVING YOUR GAME:**

Think of commits as **checkpoints/save points/bonfires**, NOT level completion:
- **Video game checkpoint** - Save after each room cleared, not after beating the entire dungeon
- **Dark Souls bonfire** - Light it whenever you reach one, don't wait until you beat the boss
- **Database transaction** - Commit small units of work frequently for rollback safety
- **Snapshot** - Capture working state often, not just "finished" state

**When to commit:**
- Added one new section to documentation
- Fixed one bug
- Implemented one function (with its test)
- Refactored one module
- Updated one configuration file
- Any change that leaves the codebase in a **usable, improved state**

**When NOT to commit:**
- Code is broken/doesn't compile
- Tests are failing (unless it's a deliberate red-phase TDD commit)
- Half-finished feature that breaks existing functionality

**The Rule:**
- **If you can describe the change in one clear sentence -> COMMIT IT**
- **If the work is "done enough" to be useful -> COMMIT IT**
- **If you'd want to roll back to this point -> COMMIT IT**

**Commit message rules:**
- **DO NOT use Co-Authored-By: Claude** - Never include Claude as a co-author
- Write in imperative mood: "Add feature" not "Added feature"
- Be descriptive: "Add validation to user signup" not "Update code"
- One logical change per commit

---

## Test-Driven Development (TDD)

**ALWAYS use TDD when implementing functionality**:
1. **Write the test first** - Start by writing a failing test that describes the desired behavior
2. **Run the test** - Verify it fails for the right reason
3. **Implement the code** - Write the minimum code to make the test pass
4. **Run the test again** - Verify it now passes
5. **Refactor** - Clean up code while keeping tests green
6. **Commit** - Make a commit with both test and implementation

---

## Code Review Mindset

When reviewing or writing code, verify:

### Functionality
- [ ] Tests are written FIRST (TDD)
- [ ] All tests pass
- [ ] Edge cases are covered
- [ ] Error handling is appropriate (not over-engineered)

### Documentation
- [ ] Public APIs are documented
- [ ] Documentation updated to reflect code changes (behavior, signatures, types, errors)

### Code Quality
- [ ] Follows language idioms
- [ ] Linting/formatting passes
- [ ] No unnecessary validations

### Architecture
- [ ] Business logic is separated from presentation/web layer
- [ ] Modules are in the right domain context
- [ ] Public APIs are clean and well-defined
- [ ] Follows existing project patterns

### Git
- [ ] Commit is focused and atomic
- [ ] Commit message is clear and descriptive
- [ ] NO "Co-Authored-By: Claude" in commit message

---

## Documentation Sync Principle

**CRITICAL: Documentation must stay in sync with code changes.**

When you change code, update the corresponding documentation:

| Code Change | Documentation to Update |
|---|---|
| **Function behavior changes** | Update docs to describe new behavior |
| **Parameters or return types change** | Update type specs / signatures |
| **New error cases added** | Document in both docs and type specs |
| **Module purpose evolves** | Update module-level documentation |

**Before committing:**
1. Review your changes - did any behavior or signatures change?
2. Read the existing documentation for modified code
3. Update documentation to reflect current reality
4. Verify type specs match actual return values and error cases
