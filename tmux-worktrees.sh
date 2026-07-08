#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
SESSION_NAME="${2:-iphone}"

# Pick the right claude launch command for a worktree based on how many prior
# conversations it has. Claude Code stores one .jsonl per conversation under
# ~/.claude/projects/<path>/, where <path> is the worktree path with every
# non-alphanumeric character replaced by a dash. A `memory` subdirectory may
# also live there, so we only count top-level .jsonl files.
#   0 conversations -> `claude`            (start fresh)
#   1 conversation  -> `claude --continue` (resume the only one)
#   2+ conversations -> `claude --resume`  (let the user pick)
claude_command_for() {
    local wt_path="$1" proj_dir count
    proj_dir="$HOME/.claude/projects/$(printf '%s' "$wt_path" | sed 's/[^a-zA-Z0-9]/-/g')"

    count=0
    if [[ -d "$proj_dir" ]]; then
        count=$(find "$proj_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "$count" -eq 1 ]]; then
        printf 'claude --continue'
    elif [[ "$count" -ge 2 ]]; then
        printf 'claude --resume'
    else
        printf 'claude'
    fi
}

# Helper: reliably launch claude in a pane.
# The shell in a freshly-split pane is still sourcing its rc files (oh-my-zsh +
# zsh-autosuggestions installs a ZLE widget on startup). Keystrokes sent during
# that window can be swallowed — most often the trailing Enter — leaving the
# fully-typed command sitting unexecuted at the prompt. We guard against this by
# clearing the line first, sending the text and Enter as separate keystrokes,
# then verifying claude actually started and resending if it did not.
send_claude() {
    local pane="$1" wt_path="$2" cmd attempt cur
    cmd=$(claude_command_for "$wt_path")

    for attempt in 1 2 3 4 5; do
        # C-u clears any partial/stale input so a resend never concatenates.
        tmux send-keys -t "$pane" C-u
        tmux send-keys -t "$pane" "$cmd"
        tmux send-keys -t "$pane" Enter

        # Give the shell up to ~3s to exec claude; pane_current_command leaves
        # the interactive shell once it does.
        local waited
        for waited in $(seq 1 12); do
            cur=$(tmux display-message -p -t "$pane" '#{pane_current_command}')
            case "$cur" in
                sh|bash|-bash|zsh|-zsh|fish|-fish|"$(basename "${SHELL:-zsh}")")
                    sleep 0.25 ;;   # still at the shell prompt — keep waiting
                *)
                    return 0 ;;     # something launched — claude is running
            esac
        done
        # Still at the shell after the grace period: the keystrokes were
        # dropped. Loop and resend.
    done
}

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
    send_claude "$win_target.2" "$wt_path"
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

# Move the master/main worktree to the front so its window is always first.
for i in "${!wt_branches[@]}"; do
    if [[ "${wt_branches[$i]}" == "master" || "${wt_branches[$i]}" == "main" ]]; then
        if [[ $i -ne 0 ]]; then
            wt_paths=("${wt_paths[$i]}" "${wt_paths[@]:0:$i}" "${wt_paths[@]:$((i+1))}")
            wt_branches=("${wt_branches[$i]}" "${wt_branches[@]:0:$i}" "${wt_branches[@]:$((i+1))}")
        fi
        break
    fi
done

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

# Ensure the master/main window is first (covers re-runs on existing sessions
# where its window may sit at a later position). base-index is 1, so index 0 is
# free; park master there, then renumber to restore a clean 1..N sequence.
master_path="${wt_paths[0]}"
master_win=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_id}	#{pane_current_path}' \
    | awk -F'\t' -v p="$master_path" '$2 == p {print $1; exit}')
if [[ -n "$master_win" ]]; then
    tmux move-window -s "$master_win" -t "$SESSION_NAME:0" 2>/dev/null || true
    tmux move-window -r -t "$SESSION_NAME" 2>/dev/null || true
fi

# Attach (select first window only for new sessions)
if ! $session_exists; then
    tmux select-window -t "$SESSION_NAME:1"
fi
exec tmux attach-session -t "$SESSION_NAME"
