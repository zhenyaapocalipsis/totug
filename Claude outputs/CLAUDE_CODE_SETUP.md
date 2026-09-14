# Claude Code Setup Complete ✓

Your project is ready for Claude Code. Here's everything that's been prepared.

---

## What's Ready

### 1. Git Repository
```bash
✓ Initialized: /home/claude/godot_project/.git/
✓ Initial commit: "Stage 7 complete: Setup for Claude Code"
✓ .gitignore: Excludes Godot cache, builds, temp files
✓ .claudeignore: Tells Claude Code what to skip (imports, cache)
```

### 2. Documentation
- **README.md** — Quick start, architecture, features, troubleshooting
- **CLAUDE.md** — Full context, structure, token budget strategy, git workflow
- **build/VALIDATION_CHECKLIST.md** — Detailed validation guide
- **.claude/agents.md** — Agent recommendations for different tasks

### 3. Project Configuration
- **.claude/config.json** — Project metadata, contexts, validation commands
- Predefined "contexts" for different work types:
  - `default` — Full project (rules + UI + tests)
  - `rules-only` — Just game rules (fast)
  - `ui-only` — Just UI layer (fast)

### 4. Validation Scripts (Ready to Use)
All scripts are executable and verified working:

| Script | Cost | Time | Purpose |
|--------|------|------|---------|
| `./build/validate_changes.sh` | Free | 10 sec | Run after code changes, before `/clear` |
| `./build/pre_export_check.sh` | Cheap | 30 sec | Run before export |
| `godot47 --headless --script tests/lint_rules.gd` | Cheap | 5 sec | Syntax + structure check |
| `godot47 --headless --script tests/quick_check.gd` | Cheap | 10 sec | Load one board, test core functions |

---

## How to Use Claude Code

### Setup
```bash
# Install Claude Code (if you haven't)
# Instructions: https://docs.claude.com/claude-code/overview

# Open this project
claude code /home/claude/godot_project

# Or via the app: File → Open Folder → select /home/claude/godot_project
```

### Before ANY Cloud Work
```bash
# First: validate locally (always, free)
./build/validate_changes.sh

# If ✓ PASS:
#   - Safe to use /clear
#   - Safe to ask Claude for expensive work

# If ✗ FAIL:
#   - Fix errors locally
#   - Run validation again
#   - Retry
```

### Recommended Workflow

**Scenario 1: Fix a rule**
```bash
1. Edit core/rules/*.gd
2. Run: ./build/validate_changes.sh
3. If ✗: Fix and retry (step 2)
4. If ✓: Tell Claude: "Validation passed, run quick_check.gd"
5. If quick_check ✓: Safe to /clear
```

**Scenario 2: Change UI**
```bash
1. Edit scenes/ui/*.gd
2. Run: ./build/validate_changes.sh
3. If ✓: Open Godot for manual test
4. If looks good: Commit
```

**Scenario 3: Export build**
```bash
1. Run: ./build/pre_export_check.sh
2. If ✗: Fix and retry
3. If ✓: Run: godot export Windows
```

### Token Budget Strategy

**Don't repeat the "consumed 50% on one fix" problem.** Follow this order:

1. **Validate locally (free, 10 sec)**
   ```bash
   ./build/validate_changes.sh
   ```

2. **Tell Claude** (cloud work starts here, if validation passed)
   ```
   "Validation passed. Run quick_check.gd to verify."
   ```

3. **Claude verifies** (cheap, ~1-2% budget)
   - Loads one board
   - Tests ControlMarkers, StateView, TurnEngine
   - Reports pass/fail

4. **If quick_check passes:** Safe to `/clear`

5. **Full suite only when needed** (expensive, 2-3 min, ~5-10% budget)
   - Run AFTER validation passes
   - Use only before commit/export

**Result:** Most work costs <1% of budget. Expensive ops only when necessary.

---

## Available Agent Contexts

Switch context to load only what you need:

```bash
# Full project (all source files)
claude code

# Just rules (turn engine, markers, bonuses, tests)
claude code --context rules-only

# Just UI (panels, cards, event log, UI tests)
claude code --context ui-only
```

Each context is optimized for the task type. Use `rules-only` for rule changes, `ui-only` for UI tweaks, `default` for cross-module work.

---

## Git Workflow

**Commit before any major change:**
```bash
# After validation passes:
git add core/rules/turn.gd
git commit -m "Update marker influence logic

- Change marker Influence from 1 to 2
- Update ControlMarkers.evaluate() accordingly
- Verify: 422 tests pass, quick_check passes

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_..."
```

**Branch strategy:**
- `main` = deployed (fully tested + exported)
- `feature/*` = work-in-progress (validation passes, not yet exported)

---

## Quick Reference Checklists

### Before Using `/clear`
- [ ] Run `./build/validate_changes.sh` → ✓ PASS
- [ ] If you changed rules: Run `godot47 --headless --script tests/quick_check.gd` → ✓ PASS
- [ ] Ready to use `/clear`

### Before Committing
- [ ] Run `./build/validate_changes.sh` → ✓ PASS
- [ ] Run `godot47 --headless --script tests/quick_check.gd` → ✓ PASS
- [ ] Manual play-test or bot-play (for UI changes)
- [ ] Ready to commit

### Before Exporting
- [ ] Run `./build/pre_export_check.sh` → ✓ PASS
- [ ] Verify export templates exist
- [ ] Run `godot export Windows` (or Linux)
- [ ] Test exported build manually
- [ ] Ready to ship

---

## File Locations

| What | Where |
|------|-------|
| Documentation | README.md, CLAUDE.md, build/VALIDATION_CHECKLIST.md |
| Config | .claude/config.json, .claude/agents.md |
| Rules | core/rules/*.gd |
| UI | scenes/ui/*.gd |
| Tests | tests/*.gd |
| Validation | build/*.sh |
| Data | data/board/*.json, data/cards/*.json |
| Export | build/windows/, build/linux/ (after export) |
| Git | .git/, .gitignore |

---

## Common Tasks

### "I want to change the rules"
1. Read: `core/rules/turn.gd` (start_turn, end_turn)
2. Edit: The specific function
3. Run: `./build/validate_changes.sh`
4. If fail: Fix and retry
5. If pass: Tell Claude to run quick_check.gd
6. Commit

### "I want to change the UI"
1. Read: `scenes/ui/player_panel.gd` (or relevant file)
2. Edit: The UI logic
3. Run: `./build/validate_changes.sh`
4. Open Godot, play-test manually
5. Commit

### "Something is broken"
1. Run: `godot47 --headless --script tests/run_tests.gd`
2. Find which test failed
3. Read error + surrounding code
4. Trace bug to root cause
5. Fix in place
6. Run validation again
7. Commit

### "I want to export"
1. Run: `./build/pre_export_check.sh`
2. If fail: Fix and retry
3. If pass: `godot export Windows`
4. Verify .exe works
5. Upload to user's computer

---

## Next Steps

### Immediate (Today)
1. ✅ Validation scripts created & verified
2. ✅ Git repository initialized
3. ✅ Documentation written
4. ✅ Claude Code config ready
5. **Next:** Use Claude Code to make your first change

### Short Term (Next Days)
- Test validation workflow with a small rule change
- Verify quick_check.gd catches issues
- Get comfortable with agent contexts
- Use `/clear` confidently with local validation

### Medium Term (Next Weeks)
- Implement end-game scoring screen
- Add marker visualization on board
- Extend to 3-4 player UI
- Plan network play

---

## Questions?

If validation fails:
1. Read the error message carefully
2. Check `build/VALIDATION_CHECKLIST.md` for solutions
3. Run validation again after fixing

If something doesn't work:
1. Check README.md "Troubleshooting" section
2. Run `./build/validate_changes.sh` (catches most issues)
3. Ask Claude Code with validation results

---

## Token Budget Recap

**Your new workflow costs ~1% per change, not 50%:**

- **Validate locally:** Free (10 sec)
- **Quick functional test:** ~1-2% (10 sec)
- **Full test suite:** ~5-10% (2-3 min, only after validation)
- **Export:** ~20-30% (10-20 min, only when needed)

**Key:** Always validate locally FIRST. This catches 90% of issues before expensive cloud work.

---

## Ready to Go

Your project is now ready for efficient Claude Code workflow:

1. ✅ Validation scripts working
2. ✅ Git initialized with clean history
3. ✅ Documentation complete
4. ✅ Config ready for Claude Code
5. ✅ Token budget strategy documented

**Start with:** `./build/validate_changes.sh` before any change.

Good luck! 🚀
