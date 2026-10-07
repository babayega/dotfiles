#!/bin/sh
# ─────────────────────────────────────────────────────────────
#  tmux status producer
#
#  Why this exists
#  ---------------
#  A `#(shell)` call inside status-right is re-executed on every status
#  redraw, and tmux rate-limits it to at most one fork per second. Each fork
#  also makes the kernel copy the server's page tables, which gets expensive
#  as scrollback grows. So the more shell calls the status line contains, the
#  more it costs.
#
#  This script inverts that: it is ONE long-lived process that polls slowly
#  and writes its findings into tmux user options. The status line then reads
#  those options as plain `#{...}` formats, which cost nothing to expand.
#  Result: git information in the bar with zero forks at draw time.
#
#  Started from tmux.conf via `run-shell -b`. If it dies, the config hook
#  restarts it on the next client attach.
# ─────────────────────────────────────────────────────────────

# The shell the panes idle in. Anything else means a command is running.
IDLE_CMD=zsh

# How often to poll. Git is cheap to skip and expensive to run, so this is
# deliberately slow; the status line stays responsive regardless because it
# is only reading an option.
POLL=3

# Hard ceiling on how often git is invoked even if the path never changes.
MAX_AGE=20

now() { date +%s; }

# Read the focused pane's path in a single tmux call. Doing this per-pane
# would mean one subprocess per pane per tick.
#
# `display-message` needs a target when no client is attached (e.g. a detached
# server), so fall back to the current session. Getting this wrong means
# @git_branch silently stays empty, which is exactly the failure mode worth
# avoiding.
active_path() {
	_p=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
	[ -z "$_p" ] && _p=$(tmux display-message -p -t '{last}' '#{pane_current_path}' 2>/dev/null)
	[ -z "$_p" ] && _p=$(tmux display-message -p -t '{start}' '#{pane_current_path}' 2>/dev/null)
	printf '%s' "$_p"
}

git_branch_for() {
	_dir=$1
	[ -d "$_dir" ] || return 0
	# Walk up looking for a repo root. This is a stat() in the common case;
	# git itself is only invoked once a repo is actually found.
	_p=$_dir
	while [ -n "$_p" ] && [ "$_p" != "/" ]; do
		if [ -e "$_p/.git" ]; then
			# Both `_b=$(cmd) || _b=""` and `[ -n "$_b" ] && _b=$(cmd) || _b=""`
			# are traps here: the `||` branch also fires when the `&&` test
			# succeeds, wiping a perfectly good value. Use explicit if/else.
			if _b=$(command git -C "$_dir" symbolic-ref --short HEAD 2>/dev/null); then
				:
			else
				_b=""
			fi
			if [ -z "$_b" ]; then
				# Detached HEAD, or a repo with no commits yet.
				if _b=$(command git -C "$_dir" rev-parse --short HEAD 2>/dev/null); then
					:
				else
					_b="detached"
				fi
			fi
			printf '%s' "$_b"
			return 0
		fi
		_p=${_p%/*}
	done
}

# ── startup ───────────────────────────────────────────────
# Mark ourselves alive so tmux.conf can detect a dead producer. The trap
# clears it on exit: without that, a crashed producer would leave the marker
# set forever and the config would never restart it.
cleanup() {
	tmux set -gu @git_producer 2>/dev/null
}
trap cleanup EXIT INT TERM

tmux set -gq @git_producer "$$"

last_path=""
last_run=0
cached=""

while :; do
	_p=$(active_path)

	# Recompute git when the directory changed, or when the cache is stale.
	# Both conditions, so a long session in one repo still refreshes.
	_t=$(now)
	_age=$((_t - last_run))
	if [ "$_p" != "$last_path" ] || [ "$_age" -ge "$MAX_AGE" ]; then
		_new=$(git_branch_for "$_p")
		if [ "$_new" != "$cached" ]; then
			cached=$_new
			# Build the ENTIRE styled module here and store it in one option.
			#
			# Why not store just the branch name and let status-right style it?
			# Because tmux expands a format in a single pass: a `#{@opt}`
			# substituted into status-right is NOT rescanned, so neither its
			# #[fg=...] styles nor any nested #{...} inside it would be
			# interpreted - they'd be printed literally. The status line gets
			# these back only via the `E:` modifier, which re-expands the
			# result (it picks up styles and formats, but deliberately does
			# NOT run #(shell) calls - which is why the battery cannot use it).
			#
			# Outside a repo the option is unset entirely, so the whole pill
			# disappears instead of leaving an empty shell behind.
			if [ -n "$cached" ]; then
				# NOTE: these are literal UTF-8 characters, not \u escapes.
				# POSIX sh does not interpret \uXXXX, so writing "\\ue0b6" would
				# put the literal text back on screen.
				module="#[fg=#a6e3a1,bg=default,nobold,nounderscore,noitalics] "
				module="${module}#[fg=#1e1e2e,bg=#a6e3a1,nobold,nounderscore,noitalics] ${cached} "
				module="${module}#[fg=#cdd6f4,bg=#313244] "
				tmux set -gq @git_module "$module"
			else
				tmux set -gu @git_module
			fi
		fi
		last_path=$_p
		last_run=$_t
	fi

	sleep "$POLL"
done
