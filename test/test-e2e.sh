#!/bin/sh
# End-to-end tests: drive ibis-mode with real keystrokes in a terminal
# Emacs running inside tmux, and assert both the buffer text (through
# emacsclient) and the rendered frame (through tmux capture-pane).

EMACS="${EMACS:-emacs}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION="ibis-e2e-$$"
DAEMON="ibis-e2e-$$"
RUN_DIR="$PROJECT_DIR/test/.run/$SESSION"
STDERR_LOG="$RUN_DIR/stderr.log"

pass=0
fail=0
frame_num=0

if ! command -v tmux >/dev/null 2>&1; then
    echo "SKIP: tmux not installed"
    exit 0
fi

mkdir -p "$RUN_DIR/frames"

cat > "$RUN_DIR/e2e-init.el" <<ELISP
;;; e2e-init.el --- Generated init for the e2e run -*- lexical-binding: t; -*-
(setq inhibit-startup-message t)
(setq make-backup-files nil)
(setq auto-save-default nil)
(add-to-list 'load-path "$PROJECT_DIR/lisp")
(require 'ibis-mode)
(setq server-name "$DAEMON")
(server-start)
ELISP

printf '? a\n  \xe2\x86\x92 b\n    + c\n\n    + d\n  \xe2\x86\x92 e\n' > "$RUN_DIR/split.ibis"

# Every tmux call goes to a private server, so that the run neither
# reads the user's tmux.conf nor changes their running server.
t() { tmux -L "$SESSION" "$@"; }

cleanup() {
    emacsclient -s "$DAEMON" -e "(kill-emacs)" >/dev/null 2>&1
    t kill-server >/dev/null 2>&1
    return 0
}
trap cleanup EXIT INT TERM

echo "tmux session: $SESSION"
echo "run directory: $RUN_DIR"

tmux -L "$SESSION" -f /dev/null new-session -d -s "$SESSION" -x 80 -y 24 \
    "$EMACS -nw --init-directory=$PROJECT_DIR/dev --load $RUN_DIR/e2e-init.el 2>$STDERR_LOG"
# Emacs reads S-<return> only as a CSI u sequence, which tmux forwards
# only with extended keys on; a zero escape time keeps M-<key> from
# being read as a lone ESC.
t set-option -g extended-keys on >/dev/null 2>&1
t set-option -s escape-time 0 >/dev/null 2>&1

waited=0
while ! emacsclient -s "$DAEMON" -e t >/dev/null 2>&1; do
    sleep 0.2
    waited=$((waited + 1))
    if [ "$waited" -ge 50 ]; then
        echo "FAIL: Emacs server did not start within 10s"
        [ -s "$STDERR_LOG" ] && cat "$STDERR_LOG"
        exit 1
    fi
done

key() { t send-keys -t "$SESSION" "$@"; }
type_text() { t send-keys -t "$SESSION" -l -- "$1"; }
meta_char() { t send-keys -t "$SESSION" Escape; t send-keys -t "$SESSION" -l -- "$1"; }

capture_frame() {
    frame_num=$((frame_num + 1))
    file=$(printf "%s/frames/%03d-%s.txt" "$RUN_DIR" "$frame_num" "$1")
    t capture-pane -t "$SESSION" -p > "$file"
    echo "$file"
}

buffer_string() {
    emacsclient -s "$DAEMON" \
        -e "(with-current-buffer \"$1\" (buffer-substring-no-properties (point-min) (point-max)))" \
        2>/dev/null
}

expect_buffer() {
    expected="\"$2\""
    actual=""
    i=0
    while [ "$i" -lt 50 ]; do
        actual=$(buffer_string "$1")
        [ "$actual" = "$expected" ] && return 0
        sleep 0.2
        i=$((i + 1))
    done
    printf '    expected buffer: %s\n' "$expected"
    printf '    actual buffer:   %s\n' "$actual"
    return 1
}

expect_frame() {
    i=0
    while [ "$i" -lt 50 ]; do
        if t capture-pane -t "$SESSION" -p 2>/dev/null | grep -qF -- "$1"; then
            return 0
        fi
        sleep 0.2
        i=$((i + 1))
    done
    printf '    frame never showed: %s\n' "$1"
    return 1
}

expect_frame_after() {
    i=0
    while [ "$i" -lt 50 ]; do
        if t capture-pane -t "$SESSION" -p 2>/dev/null \
                | grep -A1 -F -- "$1" | grep -qF -- "$2"; then
            return 0
        fi
        sleep 0.2
        i=$((i + 1))
    done
    printf '    frame never showed %s under %s\n' "$2" "$1"
    return 1
}

expect_no_tab() {
    result=$(emacsclient -s "$DAEMON" \
        -e "(with-current-buffer \"$1\" (if (string-match-p \"\\t\" (buffer-string)) \"tab\" \"clean\"))" \
        2>/dev/null)
    if [ "$result" = '"clean"' ]; then
        return 0
    fi
    echo "    buffer holds a tab character"
    return 1
}

expect_diagnostics() {
    result=$(emacsclient -s "$DAEMON" \
        -e "(with-current-buffer \"$1\" (length (cdr (ibis-parse-buffer))))" 2>/dev/null)
    if [ "$result" = "$2" ]; then
        return 0
    fi
    echo "    expected $2 diagnostics, got $result"
    return 1
}

run_step() {
    name="$1"
    shift
    if "$@"; then
        echo "  PASS  $name"
        pass=$((pass + 1))
    else
        echo "  FAIL  $name"
        fail=$((fail + 1))
        capture_frame "fail-$name" >/dev/null
    fi
}

BUFFER="e2e.ibis"
emacsclient -s "$DAEMON" -e "(find-file \"$RUN_DIR/$BUFFER\")" >/dev/null 2>&1

step_sibling_after_typing() {
    type_text "? Frage"
    key M-Enter
    type_text "Zweite"
    expect_buffer "$BUFFER" '? Frage\n\n? Zweite\n' || return 1
    capture_frame "sibling" >/dev/null
    expect_frame "? Zweite"
}

step_sibling_between_roots() {
    meta_char "<"
    key M-Enter
    type_text "Dritte"
    expect_buffer "$BUFFER" '? Frage\n\n? Dritte\n\n? Zweite\n' || return 1
    capture_frame "sibling-between-roots" >/dev/null
    expect_frame "? Dritte"
}

step_child_markers() {
    key S-Enter
    type_text "Pos"
    key S-Enter
    type_text "Pro"
    key S-Enter
    type_text "Unterfrage"
    expect_buffer "$BUFFER" \
        '? Frage\n\n? Dritte\n  → Pos\n    + Pro\n      ? Unterfrage\n\n? Zweite\n' || return 1
    capture_frame "child-markers" >/dev/null
    expect_frame "    + Pro" && expect_frame "      ? Unterfrage"
}

step_typed_arrow() {
    key M-Enter
    key BSpace BSpace
    type_text "->"
    type_text " Gegen"
    expect_buffer "$BUFFER" \
        '? Frage\n\n? Dritte\n  → Pos\n    + Pro\n      ? Unterfrage\n      → Gegen\n\n? Zweite\n' || return 1
    capture_frame "typed-arrow" >/dev/null
    expect_frame "      → Gegen"
}

step_demote_to_column_eight() {
    key M-Right
    expect_buffer "$BUFFER" \
        '? Frage\n\n? Dritte\n  → Pos\n    + Pro\n      ? Unterfrage\n        → Gegen\n\n? Zweite\n' || return 1
    expect_no_tab "$BUFFER" || return 1
    expect_diagnostics "$BUFFER" 0 || return 1
    capture_frame "demote-column-eight" >/dev/null
    expect_frame "        → Gegen"
}

step_promote_back() {
    key M-Left
    expect_buffer "$BUFFER" \
        '? Frage\n\n? Dritte\n  → Pos\n    + Pro\n      ? Unterfrage\n      → Gegen\n\n? Zweite\n'
}

step_toggle_tag() {
    key C-c t
    type_text "wichtig"
    key Enter
    expect_buffer "$BUFFER" \
        '? Frage\n\n? Dritte\n  → Pos\n    + Pro\n      ? Unterfrage\n      → Gegen #wichtig\n\n? Zweite\n' || return 1
    capture_frame "toggle-tag" >/dev/null
    expect_frame "#wichtig"
}

SPLIT="split.ibis"

step_move_down_over_blank_line() {
    emacsclient -s "$DAEMON" -e "(find-file \"$RUN_DIR/$SPLIT\")" >/dev/null 2>&1
    expect_buffer "$SPLIT" '? a\n  → b\n    + c\n\n    + d\n  → e\n' || return 1
    meta_char "<"
    key Down
    key M-Down
    expect_buffer "$SPLIT" '? a\n  → e\n  → b\n    + c\n\n    + d\n' || return 1
    expect_diagnostics "$SPLIT" 0 || return 1
    capture_frame "move-down" >/dev/null
    expect_frame_after "? a" "  → e"
}

step_move_up_restores() {
    key M-Up
    expect_buffer "$SPLIT" '? a\n  → b\n    + c\n\n    + d\n  → e\n' || return 1
    expect_diagnostics "$SPLIT" 0
}

step_flymake_reports_a_stray_argument() {
    meta_char ">"
    type_text "? Falsch"
    key Enter
    type_text "  + Schlecht"
    expect_diagnostics "$SPLIT" 1 || return 1
    key C-c C-c
    expect_frame "Argument must support a position" || return 1
    capture_frame "flymake" >/dev/null
    return 0
}

echo ""
echo "=== End-to-end tests ==="
run_step "sibling-after-typing" step_sibling_after_typing
run_step "sibling-between-roots" step_sibling_between_roots
run_step "child-markers" step_child_markers
run_step "typed-arrow" step_typed_arrow
run_step "demote-to-column-eight" step_demote_to_column_eight
run_step "promote-back" step_promote_back
run_step "toggle-tag" step_toggle_tag
run_step "move-down-over-blank-line" step_move_down_over_blank_line
run_step "move-up-restores" step_move_up_restores
run_step "flymake-stray-argument" step_flymake_reports_a_stray_argument

echo ""
echo "=== Summary ==="
echo "$((pass + fail)) steps: $pass passed, $fail failed"
echo "frames in $RUN_DIR/frames"

if [ "$fail" -gt 0 ]; then
    if [ -s "$STDERR_LOG" ]; then
        echo "--- stderr.log ---"
        tail -20 "$STDERR_LOG"
    fi
    exit 1
fi
exit 0
