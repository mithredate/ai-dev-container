---
name: ralph
description: "Convert PRDs to prd.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format, OR when you need to cleanup completed stories. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json, cleanup prd, archive completed stories."
---

# Ralph PRD Converter

Converts existing PRDs to the prd.json format that Ralph uses for autonomous execution. Also handles cleanup of completed stories.

---

## The Job

**Convert mode:** Take a PRD (markdown file or text) and append stories to `prd.json` in your ralph directory.

**Cleanup mode:** Archive completed stories (`passes: true`) from prd.json.

---

## Output Format

**Branch name prefixes:**
- `feat/` - new feature
- `fix/` - bug fix
- `chore/` - maintenance, config, dependencies
- `refactor/` - code restructuring
- `docs/` - documentation only
- `test/` - adding/updating tests

```json
{
  "project": "[Project Name]",
  "branchName": "[type]/[short-description-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Amp instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

### Always include as final criterion:
```
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

### For stories that change UI, also include:
```
"Verify in browser using dev-browser skill"
```

Frontend stories are NOT complete until visually verified. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Continue from existing stories (see "Adding to Existing prd.json" below)
3. **Priority**: Recalculate for ALL stories based on dependency order
4. **New stories**: `passes: false` and empty `notes`
5. **branchName**: Use conventional prefix (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`, `test/`) + short description in kebab-case
6. **Always add**: "Typecheck passes" to every story's acceptance criteria

---

## Adding to Existing prd.json

**IMPORTANT: Always read existing prd.json before writing new stories.**

### Steps:

1. **Read existing prd.json** if it exists
2. **Find the highest story ID** (e.g., if US-007 exists, next is US-008)
3. **Keep all existing stories** - do not remove or modify them
4. **Append new stories** with IDs continuing the sequence
5. **Reprioritize ALL stories** (existing + new) based on dependency order

### ID Sequencing Example:

**Existing prd.json has:**
- US-001, US-002, US-003

**New PRD adds 2 stories:**
- New story 1 → US-004
- New story 2 → US-005

### Priority Recalculation:

When adding new stories, analyze dependencies across ALL stories (existing + new) and reassign priorities:

1. List all stories (existing + new)
2. Build dependency graph (which stories depend on which)
3. Assign priorities so no story depends on a higher-priority story
4. Stories with `passes: true` should generally keep lower priorities (they're done)

**Example:**
- Existing US-001 (passes: true, priority: 1) - schema change
- Existing US-002 (passes: false, priority: 2) - uses schema
- New US-003 - new schema change (must run before US-002)

After reprioritization:
- US-001: priority 1 (done, schema)
- US-003: priority 2 (new schema, must run before US-002)
- US-002: priority 3 (depends on both schemas)

---

## Cleanup Mode

When the user asks to **cleanup** or **archive completed stories**, follow these steps:

### Trigger phrases:
- "cleanup prd"
- "archive completed stories"
- "remove passed stories"

### Cleanup Steps:

1. **Read current prd.json**
2. **Identify stories with `passes: true`**
3. **Archive them:**
   - Create archive folder: `archive/YYYY-MM-DD-cleanup/`
   - Save completed stories to `archive/YYYY-MM-DD-cleanup/completed-stories.json`
   - Copy current `progress.txt` to archive
4. **Update prd.json:**
   - Remove all stories with `passes: true`
   - Keep all stories with `passes: false`
   - Recalculate priorities for remaining stories (1, 2, 3, ...)
5. **Reset progress.txt** with fresh header

### Cleanup Example:

**Before cleanup (prd.json):**
```json
{
  "userStories": [
    {"id": "US-001", "passes": true, "priority": 1},
    {"id": "US-002", "passes": true, "priority": 2},
    {"id": "US-003", "passes": false, "priority": 3},
    {"id": "US-004", "passes": false, "priority": 4}
  ]
}
```

**After cleanup (prd.json):**
```json
{
  "userStories": [
    {"id": "US-003", "passes": false, "priority": 1},
    {"id": "US-004", "passes": false, "priority": 2}
  ]
}
```

**Archived (completed-stories.json):**
```json
{
  "archivedAt": "2024-01-15",
  "stories": [
    {"id": "US-001", "passes": true, "priority": 1},
    {"id": "US-002", "passes": true, "priority": 2}
  ]
}
```

Note: Story IDs are NOT renumbered during cleanup - US-003 stays US-003. Only priorities are recalculated.

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. US-001: Add notifications table to database
2. US-002: Create notification service for sending notifications
3. US-003: Add notification bell icon to header
4. US-004: Create notification dropdown panel
5. US-005: Add mark-as-read functionality
6. US-006: Add notification preferences page

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output prd.json:**
```json
{
  "project": "TaskApp",
  "branchName": "feat/task-status",
  "description": "Task Status Feature - Track task progress with status indicators",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field to tasks table",
      "description": "As a developer, I need to store task status in the database.",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Display status badge on task cards",
      "description": "As a user, I want to see task status at a glance.",
      "acceptanceCriteria": [
        "Each task card shows colored status badge",
        "Badge colors: gray=pending, blue=in_progress, green=done",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-003",
      "title": "Add status toggle to task list rows",
      "description": "As a user, I want to change task status directly from the list.",
      "acceptanceCriteria": [
        "Each row has status dropdown or toggle",
        "Changing status saves immediately",
        "UI updates without page refresh",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 3,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-004",
      "title": "Filter tasks by status",
      "description": "As a user, I want to filter the list to see only certain statuses.",
      "acceptanceCriteria": [
        "Filter dropdown: All | Pending | In Progress | Done",
        "Filter persists in URL params",
        "Typecheck passes",
        "Verify in browser using dev-browser skill"
      ],
      "priority": 4,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Archiving Previous Runs

**Before writing a new prd.json, check if there is an existing one from a different feature:**

1. Read the current `prd.json` if it exists
2. Check if `branchName` differs from the new feature's branch name
3. If different AND `progress.txt` has content beyond the header:
    - Create archive folder: `archive/YYYY-MM-DD-feature-name/`
    - Copy current `prd.json` and `progress.txt` to archive
    - Reset `progress.txt` with fresh header

**The ralph.sh script handles this automatically** when you run it, but if you are manually updating prd.json between runs, archive first.

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] **Read existing prd.json first** (if it exists)
- [ ] **Story IDs continue from highest existing ID** (not starting from US-001)
- [ ] **Previous run archived** (if prd.json exists with different branchName, archive it first)
- [ ] Each story is completable in one iteration (small enough)
- [ ] **All priorities recalculated** based on dependencies (existing + new stories)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using dev-browser skill" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a higher-priority story
