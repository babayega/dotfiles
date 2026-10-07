# dotfiles

tmux + Neovim + Ghostty, tuned for macOS on Apple Silicon.

Themes are [Catppuccin Mocha](https://catppuccin.com) across all three tools.

```
.
├── install.sh          symlinks everything into ~/.config
├── nvim/               LazyVim (Neovim 0.12+)
│   ├── init.lua
│   ├── lazyvim.json
│   ├── lazy-lock.json  ← the rollback safety net; keep it in git
│   └── lua/
├── tmux/               catppuccin/tmux + hand-written additions
│   ├── tmux.conf
│   └── scripts/
│       ├── git-producer.sh   feeds the git branch into the status bar
│       └── cheatsheet.sh     generates cheatsheet.md from live keymaps
├── ghostty/config
└── shell/.zshrc
```

## Layout: this repo is the only source of truth

`~/.config/{nvim,tmux,ghostty}` and `~/.zshrc` are **symlinks into this repo**,
not copies. Edit here, and the running setup changes with it:

```sh
$ ls -l ~/.config/tmux
lrwxr-xr-x  ~/.config/tmux -> ~/dotfiles/tmux
```

Only two things are deliberately *not* tracked:

| Path | Why |
| --- | --- |
| `tmux/plugins/` | ~6 MB of TPM-managed checkouts, recreated by `prefix + I` |
| `tmux/cheatsheet.md` | generated; embeds machine-specific absolute paths |

## Install

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Existing directories are **moved aside**, not deleted. Use `--force` to
overwrite without a backup.

Then inside tmux press `prefix + I` to fetch plugins, and restart Ghostty once.

## Notable choices

**tmux stays on 3.6a.** 3.7c ships floating panes but also carries a macOS
hang ([#5510](https://github.com/tmux/tmux/issues/5510)) that kills the server
and needs `SIGKILL` to recover. 3.7 is only worth it once 3.8 is stable.

**The status bar avoids `#(shell)` where it can.** A `#(shell)` call is
re-executed on every status redraw, rate-limited to one fork per second, and
each fork makes the kernel copy the server's page tables. Git branch state
therefore comes from a single long-lived producer writing a pre-styled
`@git_module`, which the bar reads as a plain format — zero forks at draw
time. The battery genuinely needs a shell call, so it stays as two.

**tmux expands formats in a single pass.** A `#(shell)` call nested inside
`#{...}` is printed as literal text, never executed — the cause of a bug where
the battery showed its own command string instead of running. `#{E:@option}`
re-expands styles and formats but deliberately does *not* run shell calls,
which is why the git module uses it and the battery cannot.

**Shell startup is 0.10s.** oh-my-zsh was being sourced twice, once without
plugins and once with. ~0.6s recovered per shell.

**Light/dark terminal theming is deliberately absent.** tmux 3.6a has no
`set -s theme` and exposes no format for the terminal's background colour, so
the bar cannot learn the terminal switched to Latte — leaving a dark bar on a
light terminal. Available once tmux 3.8 ships.

## Cheatsheet

`cheat` opens a reference generated from your **live** keymaps, so it can't
drift out of date. Regenerate with `cheat-refresh` or `prefix + F1`.

## Slow command alerts

Any command over 45s raises a notification. Implemented in zsh's
`preexec`/`precmd` hooks, so the timing is exact with no background poller.

| Variable | Effect |
| --- | --- |
| `CMD_SLOW_THRESHOLD=90` | change the 45s threshold, per session |
| `CMD_SLOW_VERBOSE=1` | also print the timing inline |
| `TMUX_CMD_SLOW=0` | disable the notification |

## Requirements

tmux 3.6+, Neovim 0.12+, Ghostty 1.3+, `tree-sitter` CLI and a C compiler
(for nvim-treesitter `main`), zsh, oh-my-zsh.