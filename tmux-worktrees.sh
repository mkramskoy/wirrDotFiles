#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
SESSION_NAME="${2:-iphone}"

# Helper: create a window with two vertical panes for a worktree
create_window() {
    local session="$1" win_name="$2" wt_path="$3" new_session="$4"

    if [[ "$new_session" == "true" ]]; then
        tmux new-session -d -s "$session" -n "$win_name" -c "$wt_path"
    else
        tmux new-window -t "$session" -n "$win_name" -c "$wt_path"
    fi

    # Target the newly created window by its ID to avoid name-parsing issues
    local win_target
    win_target=$(tmux list-windows -t "$session" -F '#{window_id}' | tail -1)

    # Prevent Claude Code from overwriting the window name
    tmux set-window-option -t "$win_target" allow-rename off
    tmux set-window-option -t "$win_target" automatic-rename off

    # Split vertically (side by side): left = shell, right = claude
    tmux split-window -h -t "$win_target" -c "$wt_path"
    tmux send-keys -t "$win_target.2" "claude --continue" Enter
    tmux select-pane -t "$win_target.1"
}

# Collect worktrees: parallel arrays for path and branch name
wt_paths=()
wt_branches=()
while IFS= read -r line; do
    wt_path=$(echo "$line" | awk '{print $1}')
    # Extract branch name from [brackets], or fall back to directory basename
    branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]/\1/p')
    [[ -z "$branch" ]] && branch=$(basename "$wt_path")
    wt_paths+=("$wt_path")
    # Use short name: strip "username/" prefix (e.g. "mkramskoy/feature" → "feature")
    wt_branches+=("${branch##*/}")
done < <(git -C "$REPO_DIR" worktree list)

if [[ ${#wt_paths[@]} -eq 0 ]]; then
    echo "No worktrees found in $REPO_DIR"
    exit 1
fi

# If session already exists, detect windows by pane working directories (robust
# against Claude Code renaming window titles via escape sequences).
session_exists=false
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    session_exists=true
    existing_pane_paths=$(tmux list-panes -s -t "$SESSION_NAME" -F '#{pane_current_path}' | sort -u)
fi

# Remove windows for worktrees that no longer exist
if $session_exists; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        win_id=$(echo "$line" | cut -f1)
        pane_path=$(echo "$line" | cut -f2)
        match=false
        for wt_path in "${wt_paths[@]}"; do
            [[ "$pane_path" == "$wt_path" ]] && { match=true; break; }
        done
        if ! $match; then
            tmux kill-window -t "$win_id" 2>/dev/null || true
        fi
    done < <(tmux list-windows -t "$SESSION_NAME" -F '#{window_id}	#{pane_current_path}')
fi

first_new=true
for i in "${!wt_paths[@]}"; do
    wt_path="${wt_paths[$i]}"
    win_name="${wt_branches[$i]}"

    if $session_exists; then
        # Check if any existing pane already has this worktree as its working directory
        if echo "$existing_pane_paths" | grep -qxF "$wt_path"; then
            continue
        fi
        create_window "$SESSION_NAME" "$win_name" "$wt_path" false
    else
        if $first_new; then
            create_window "$SESSION_NAME" "$win_name" "$wt_path" true
            first_new=false
        else
            create_window "$SESSION_NAME" "$win_name" "$wt_path" false
        fi
    fi
done

# Attach (select first window only for new sessions)
if ! $session_exists; then
    tmux select-window -t "$SESSION_NAME:1"
fi
exec tmux attach-session -t "$SESSION_NAME"
