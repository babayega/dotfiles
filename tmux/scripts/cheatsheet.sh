#!/bin/sh
# ─────────────────────────────────────────────────────────────
#  Generates ~/.config/tmux/cheatsheet.md from the LIVE bindings.
#
#  Reading keymaps out of tmux (rather than maintaining a markdown file by
#  hand) means the cheatsheet cannot drift from the actual config. Run it
#  with `cheat-refresh`.
# ─────────────────────────────────────────────────────────────

OUT="${CHEATSHEET_OUT:-$HOME/.config/tmux/cheatsheet.md}"
TMUX_CONF="$HOME/.config/tmux/tmux.conf"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Normalise `tmux list-keys` output into "<key>  <command>".
#
# The raw format is "bind-key [-r] [-T <table>] <key> <command>", so neither
# the key nor the command sits at a fixed field. Strip the verb, the flags and
# the table spec, drop the root table (mouse / terminal-emulator keys are not
# interesting here), and skip the ~150 built-in bindings whose descriptions
# are pure noise in a human-facing reference.
tmux list-keys -T prefix 2>/dev/null | awk '
	/^-T root /          { next }
	{
		line = $0
		sub(/^bind-key[ \t]+/, "", line)
		sub(/^-[a-zA-Z]+ /, "", line)      # -r, -n, -a, ...
		sub(/^-T [a-z-]+ /, "", line)      # -T prefix
		if (line == "") next

		# Drop tmux'"'"'s built-in editing/navigation bindings.
		if (line ~ /Copies the selected|Scrolls up|Scrolls down|Sends prefix|Writes text|Enters copy|Display of panes|Suspends|Force kill|Pastes|Prevents|Sends the keys|Copies the empty|Cursor position|Selects|Clears the|Create a new|Removes a|Move window|Move pane|Swap pane|Previous layout|Select layout|Next layout|Vertical |Horizontal |Clock|Command prompt|Beginning of line|Move cursor|Enter or leave|Show messages|Kill pane|Kill window|Kill server|Display client|Spawn|Choose |Jump to|Select pane|Respawn|Split window|New window|Rename |Toggle |Refresh|Split pane|Display pane|Send keys|List |Show |Set |Choose|Swap |Move |Server|Client|Setw|Setg|set |New-pane|new-pane/)
			next

		# Normalise whitespace runs so columns line up.
		gsub(/[ \t]+/, " ", line)
		sub(/ /, "  ")
		print line
	}
' | sort -u > "$TMP"

emit() { # emit <heading> <regex> <note>
	echo "## $1"
	echo
	[ -n "$3" ] && { echo "$3"; echo; }
	echo '```'
	grep -E "$2" "$TMP" || echo "  (none bound)"
	echo '```'
	echo
}

{
	echo "# tmux cheatsheet"
	echo
	echo "Prefix is **Ctrl+a**. Double-tap to send a literal Ctrl+a."
	echo
	printf 'Generated from the live tmux server on %s.\n' "$(date '+%Y-%m-%d %H:%M')"
	echo
	echo "This file is generated. Edit \`$TMUX_CONF\` or \`$HOME/.zshrc\` and"
	echo "re-run \`cheat-refresh\` - it reads the real keymaps, so it cannot go stale."
	echo
	echo "## Quick reference"
	echo
	echo "| What | Key |"
	echo "| --- | --- |"
	echo "| Reload config | \`prefix + r\` |"
	echo "| Fuzzy window switcher | \`prefix + Tab\` |"
	echo "| Fuzzy session switcher | \`prefix + Shift-Tab\` |"
	echo "| Vertical split | \`prefix + -\` |"
	echo "| Horizontal split | \`prefix + |\` |"
	echo "| Zoom pane | \`prefix + z\` |"
	echo "| Cycle panes | \`prefix + o\` |"
	echo "| Move between panes (nvim or shell) | \`Ctrl+h/j/k/l\` |"
	echo
	emit "Panes" ' (split-window|select-pane|resize-pane|last-pane|swap-pane|join-pane|break-pane|list-panes|display-panes|respawn-pane|clear-history|clear-pane)'
	emit "Windows" ' (new-window|next-window|previous-window|last-window|next-layout|previous-layout|select-layout|rename-window|kill-window|move-window|link-window)'
	emit "Sessions" ' (new-session|next-session|previous-session|last-session|rename-session|kill-session|attach-session|detach-client|list-sessions|switch-client|choose-client|rename-session)'
	emit "Copy mode" 'copy-mode'
	emit "Switchers" 'choose-'
	emit "Everything else" '.' ''

	echo "## Shell side"
	echo
	echo '```'
	echo "  cheat            open this file"
	echo "  cheat-refresh    regenerate it from the live keymaps"
	echo "  TMUX_CMD_SLOW=0            disable the slow-command notification"
	echo "  CMD_SLOW_VERBOSE=1         also print the timing inline"
	echo "  CMD_SLOW_THRESHOLD=<n>     change the 45s threshold (per session)"
	echo '```'
	echo
	echo "## How the status bar is built"
	echo
	echo '```'
	echo "  battery    two #(shell) calls at the TOP level of status-right"
	echo "  git branch one long-lived producer writes @git_module; the bar"
	echo "             reads it with #{E:@git_module}"
	echo
	echo "  tmux expands a format in a single pass: a shell call nested inside"
	echo "  #{...} is printed as text, never executed. #{E:@opt} re-expands"
	echo "  styles and formats but deliberately does NOT run #(shell)."
	echo '```'
} > "$OUT"

echo "wrote $OUT ($(grep -cv '^$' "$OUT") non-empty lines)"
