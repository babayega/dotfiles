#!/usr/bin/env bash
# Install these dotfiles by symlinking them into ~/.config.
#
# Safe to re-run: existing directories are moved aside (not deleted) before
# being replaced, so nothing is lost if you have local edits.
#
#   ./install.sh          install everything
#   ./install.sh --force  overwrite without keeping a backup

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

say() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

link_dir() {
	local name="$1" src="$REPO/$1"
	[ -e "$src" ] || return 0

	local dest="$CONFIG/$name"

	if [ -e "$dest" ] && [ ! -L "$dest" ]; then
		if [ "$FORCE" -eq 1 ]; then
			warn "$dest exists and is not a symlink; --force given, removing"
			rm -rf "$dest"
		else
			local backup="$dest.backup.$(date +%Y%m%d-%H%M%S)"
			warn "$dest is not a symlink; moving to $backup"
			mv "$dest" "$backup"
		fi
	fi

	mkdir -p "$CONFIG"
	ln -sfn "$src" "$dest"
	say "linked $dest -> $src"
}

# --- preflight -------------------------------------------------------------
command -v tmux >/dev/null   || warn "tmux not installed"
command -v nvim >/dev/null   || warn "neovim not installed"
command -v git  >/dev/null   || warn "git not installed"

# --- go --------------------------------------------------------------------
say "installing config"
link_dir nvim
link_dir tmux
link_dir ghostty

# --- shell -----------------------------------------------------------------
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
	if [ "$FORCE" -eq 1 ]; then
		warn "~/.zshrc exists and is not a symlink; --force given, replacing"
	else
		cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d-%H%M%S)"
		warn "backed up existing ~/.zshrc"
	fi
fi
ln -sfn "$REPO/shell/.zshrc" "$HOME/.zshrc"
say "linked ~/.zshrc -> $REPO/shell/.zshrc"

# --- post-install ----------------------------------------------------------
# Plugins are fetched by TPM, not vendored in git.
if [ -x "$CONFIG/tmux/scripts/cheatsheet.sh" ]; then
	"$CONFIG/tmux/scripts/cheatsheet.sh" >/dev/null 2>&1 \
		&& say "generated tmux/cheatsheet.md (run 'cheat' to read it)" \
		|| warn "could not generate the cheatsheet yet (tmux must be running)"
fi

cat <<EOF

  Done. Next steps:

    1. Install plugins:   prefix + I   (TPM, inside tmux)
    2. Reload tmux:       prefix + r
    3. Restart Ghostty once so background-opacity / blur / titlebar apply.

  Optional:
    - Grant Ghostty Accessibility (System Settings > Privacy & Security).
      Required for the cmd+\` quick terminal; without it Ghostty 1.3.1 leaks a
      Mach port per second and is eventually killed.
    - The status bar shows a git branch via a background producer. It starts
      automatically on first tmux load.

EOF