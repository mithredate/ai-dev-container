#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [max_iterations]

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
TASK_DIRECTORY="$(dirname "${SCRIPT_DIR}")/tasks"

# Session limit retry settings
SESSION_LIMIT_WAIT=1200  # 20 minutes between retries
SESSION_LIMIT_PATTERN="session limit reached\|rate limit\|too many requests"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip conventional commit prefixes from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed -E 's#^(chore|feat|fix|refactor|docs|style|test|perf|ci|build|revert)/##')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Commit PRD and archives at the start of a new cycle
commit_ralph_files() {
  echo "Committing Ralph files (prd.json, progress, archives, tasks)..."
  
  # Add prd.json if it exists
  if [ -f "$PRD_FILE" ]; then
    git add "$PRD_FILE" 2>/dev/null || true
  fi
  
  # Add progress file if it exists
  if [ -f "$PROGRESS_FILE" ]; then
    git add "$PROGRESS_FILE" 2>/dev/null || true
  fi
  
  # Add archive directory if it exists
  if [ -d "$ARCHIVE_DIR" ]; then
    git add "$ARCHIVE_DIR" 2>/dev/null || true
  fi

  # Add tasks directory if it exists
  if [ -d "$TASK_DIRECTORY" ]; then
    git add "$TASK_DIRECTORY" 2>/dev/null || true
  fi

  # Commit if there are staged changes
  if git diff --cached --quiet 2>/dev/null; then
    echo "   No Ralph files to commit"
  else
    git commit -m "chore: update ralph files (prd, progress, tasks)" 2>/dev/null || true
    echo "   Committed Ralph files"
  fi
}

# Ensure we're on the correct branch before starting
if [ -f "$PRD_FILE" ]; then
  EXPECTED_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  ACTUAL_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

  if [ -n "$EXPECTED_BRANCH" ] && [ "$EXPECTED_BRANCH" != "$ACTUAL_BRANCH" ]; then
    echo "Switching to branch: $EXPECTED_BRANCH"
    # Try to checkout existing branch, or create new one
    if ! git checkout "$EXPECTED_BRANCH" 2>/dev/null; then
      echo "   Branch doesn't exist, creating it..."
      git checkout -b "$EXPECTED_BRANCH"
    fi
    echo "   Now on branch: $(git branch --show-current)"
  fi

  # Commit Ralph files at the start of the cycle
  commit_ralph_files
fi

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # Run claude with retry logic for session limits
  while true; do
    OUTPUT=$(cat "$SCRIPT_DIR/claude.prompt.md" | docker compose exec -T -e CLAUDE_STARTING=1 claude claude 2>&1 | tee /dev/stderr) || true

    # Check for session limit
    if echo "$OUTPUT" | grep -qi "$SESSION_LIMIT_PATTERN"; then
      echo ""
      echo "⏳ Session limit reached. Waiting $SESSION_LIMIT_WAIT seconds..."
      echo "   Time: $(date)"
      echo "   Will retry at: $(date -d "+$SESSION_LIMIT_WAIT seconds" 2>/dev/null || date -v+${SESSION_LIMIT_WAIT}S 2>/dev/null || echo "in $SESSION_LIMIT_WAIT seconds")"
      sleep $SESSION_LIMIT_WAIT
      echo "   Retrying..."
      continue
    fi
    
    # No session limit, break out of retry loop
    break
  done

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1