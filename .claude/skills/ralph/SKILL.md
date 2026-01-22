---
name: ralph
description: "Convert PRDs to prd.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format, OR when you need to cleanup completed stories. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json, cleanup prd, archive completed stories."
---

# Ralph PRD Converter

**Convert mode:** Take a PRD (from `tasks/prd-*.md` or provided text) and append stories to `ralph/prd.json`.
**Cleanup mode:** Archive completed stories (`passes: true`) from prd.json.

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "[conventional-prefix]/[kebab-case-description]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": ["Criterion 1", "Typecheck passes"],
      "priority": 1,
      "passes": false,
      "attempts": 0,
      "notes": ""
    }
  ]
}
```

## Critical Constraint: Story Size

**Each story must be completable in ONE Ralph loop iteration (one context window).**

Ralph spawns a fresh instance per iteration with no memory of previous work. Too-large stories cause context exhaustion and broken code.

**Split these:**
- "Build the dashboard" → schema, queries, UI components, filters (separate stories)
- "Add authentication" → schema, middleware, login UI, session handling

## Required Acceptance Criteria

Every story must end with: `"Typecheck passes"`

UI stories must also include: `"Verify in browser using dev-browser skill"`

Stories with testable logic: `"Tests pass"`

## Adding to Existing prd.json

**Always read existing prd.json first.**

1. Continue IDs from highest existing (US-007 exists → next is US-008)
2. Keep all existing stories unchanged
3. Append new stories
4. Reprioritize ALL stories based on dependencies (schema → backend → UI)
5. Stories with `passes: true` keep lower priorities

## Archiving Previous Runs

Before writing prd.json for a **different feature**:

1. Check if existing `branchName` differs from new feature
2. If different and `progress.txt` has content:
   - Archive to `archive/YYYY-MM-DD-feature-name/`
   - Copy `prd.json` and `progress.txt` to archive
   - Reset `progress.txt`

## Cleanup Mode

Triggers: "cleanup prd", "archive completed stories", "remove passed stories"

1. Archive stories with `passes: true` to `archive/YYYY-MM-DD-cleanup/completed-stories.json`
2. Copy `progress.txt` to archive
3. Remove passed stories from prd.json (keep IDs unchanged, recalculate priorities)
4. Reset `progress.txt`

Archive format:
```json
{"archivedAt": "YYYY-MM-DD", "stories": [...]}
```
