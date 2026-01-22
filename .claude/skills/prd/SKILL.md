---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when: planning a feature, starting a new project, user asks to 'create a prd', 'write prd for', 'plan this feature', 'requirements for', or 'spec out'."
---

# PRD Generator

## Workflow

1. Receive feature description
2. Ask 3-5 clarifying questions (lettered options for quick "1A, 2C, 3B" responses)
3. Generate PRD
4. Save to `tasks/prd-[feature-name].md`

**Do NOT implement. Only create the PRD.**

## Clarifying Questions

Ask only where the prompt is ambiguous. Focus on:
- Problem/Goal
- Core functionality
- Scope boundaries
- Success criteria

Format with lettered options:
```
1. What is the primary goal?
   A. Improve onboarding
   B. Increase retention
   C. Reduce support burden
   D. Other: [specify]
```

## PRD Template

```markdown
# PRD: [Feature Name]

## Overview
[Problem and solution in 2-3 sentences]

## Goals
- [Specific, measurable objective]

## User Stories

### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Invariants:**
* [State/Condition that must be preserved]

**Acceptance Criteria:**
- [ ] [Verifiable criterion - not "works correctly"]
- [ ] Typecheck/lint passes
- [ ] [UI stories] Verify in browser using dev-browser skill

## Functional Requirements
- FR-1: [Explicit, unambiguous requirement]

## Non-Goals
- [What this will NOT include]

## Technical Considerations (if relevant)
- [Constraints, dependencies, integrations]

## Success Metrics
- [How success is measured]

## Open Questions
- [Remaining uncertainties]
```

## Key Guidelines

**User stories:** Small enough for one focused session. Each acceptance criterion must be verifiable.

**UI stories:** Always include "Verify in browser using dev-browser skill" in acceptance criteria.

**Audience:** Write for junior developers or AI agents—be explicit, avoid jargon, use numbered requirements.

## Example

```markdown
# PRD: Task Priority System

## Overview
Add priority levels (high/medium/low) to tasks with visual indicators and filtering.

## Goals
- Assign priority to any task
- Visual differentiation between levels
- Filter and sort by priority
- Default new tasks to medium

## User Stories

### US-001: Add priority field to database
**Description:** As a developer, I need to store task priority so it persists.

**Acceptance Criteria:**
- [ ] Add priority column: 'high' | 'medium' | 'low' (default 'medium')
- [ ] Migration runs successfully
- [ ] Typecheck passes

### US-002: Display priority indicator
**Description:** As a user, I want to see priority at a glance.

**Acceptance Criteria:**
- [ ] Colored badge on task cards (red=high, yellow=medium, gray=low)
- [ ] Visible without interaction
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-003: Priority selector in task edit
**Description:** As a user, I want to change priority when editing.

**Acceptance Criteria:**
- [ ] Dropdown in edit modal
- [ ] Shows current priority selected
- [ ] Saves on change
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-004: Filter by priority
**Description:** As a user, I want to filter to high-priority items.

**Acceptance Criteria:**
- [ ] Filter dropdown: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Empty state when no matches
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

## Functional Requirements
- FR-1: Add `priority` field ('high' | 'medium' | 'low', default 'medium')
- FR-2: Colored priority badge on task cards
- FR-3: Priority selector in edit modal
- FR-4: Priority filter in list header
- FR-5: Sort by priority within columns

## Non-Goals
- Priority-based notifications
- Automatic priority from due date
- Priority inheritance for subtasks

## Technical Considerations
- Reuse existing badge component
- Filter state via URL params

## Success Metrics
- Priority change in under 2 clicks
- High-priority visible at top
- No performance regression

## Open Questions
- Priority affect ordering within columns?
- Keyboard shortcuts for priority?
```
