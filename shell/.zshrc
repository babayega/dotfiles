# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable oh-my-zsh theme (Starship handles the prompt)
ZSH_THEME=""

# Minimal prompt for Cursor/VSCode, Starship everywhere else
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
fi

# Load Oh My Zsh
# NOTE: plugins= must be set BEFORE sourcing, and this must be the only
# source of oh-my-zsh.sh. Sourcing it twice (once without plugins, once
# with) doubled interactive shell startup from ~0.08s to ~0.70s.
plugins=(git brew fzf zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

command -v kubectl &>/dev/null && source <(kubectl completion zsh)
export PATH="$HOME/.local/bin:$PATH"
command -v go &>/dev/null && export PATH="$PATH:$(go env GOPATH)/bin"

# ─── History Optimization ────────────────

HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY          # Share history across all sessions
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS     # Remove extra blanks from commands
setopt HIST_IGNORE_SPACE      # Don't save commands starting with space

# Up/Down arrow prefix search (type "git" then press up to cycle git commands)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# ─── Layer 3: Tool Integrations ──────────

# Zoxide (smarter cd)
eval "$(zoxide init zsh)"

# ─── Layer 3: Aliases ────────────────────

# eza (modern ls)
alias ls="eza --icons"
alias ll="eza --icons -la --git"
alias la="eza --icons -a"
alias tree="eza --icons --tree --level=3"

# bat (modern cat)
alias cat="bat --paging=never"

# cheatsheet - generated from the live tmux keymaps, so it cannot go stale
alias cheat="bat --paging=never ~/.config/tmux/cheatsheet.md"
cheat-refresh() { ~/.config/tmux/scripts/cheatsheet.sh }

# nvim replaces vim
alias vim="nvim"
alias vi="nvim"

# fastfetch on new terminal (only in interactive non-tmux shells)
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
  fastfetch
fi

# ─── Slow command alerts ─────────────────
# Notifies when a command takes longer than CMD_SLOW_THRESHOLD seconds.
#
# Done in the shell rather than with a background poller: preexec fires
# before each command and precmd after, so the elapsed time is known exactly
# with no daemon, no polling and no subprocess. (tmux 3.8 has a
# `pane-command-finished` hook for this, but we are staying on 3.6a.)
#
# Set TMUX_CMD_SLOW=0 to disable, or override the threshold per-session.
: ${CMD_SLOW_THRESHOLD:=45}
: ${CMD_SLOW_VERBOSE:=0}

typeset -g _cmd_started=0
typeset -g _cmd_text=""

_preexec() {
  _cmd_started=$EPOCHREALTIME
  # Take the command from preexec's $1 rather than $history[1] in precmd:
  # hook ordering means history[1] is not yet the command that just ran.
  _cmd_text=$1
  # Expose the running command to tmux as a *pane* option, so the status bar
  # can show it with a plain #{...} format (free) rather than a #(shell) call.
  [[ -n "$TMUX" ]] && tmux set -pq @cmd_running "${_cmd_text%% *}" 2>/dev/null
}

_precmd() {
  [[ -n "$TMUX" ]] && tmux set -pqu @cmd_running 2>/dev/null
  (( _cmd_started == 0 )) && return
  local -i elapsed=$(( EPOCHREALTIME - _cmd_started ))
  _cmd_started=0
  if (( elapsed >= CMD_SLOW_THRESHOLD )); then
    local -r h=$(( elapsed / 3600 )) m=$(( (elapsed % 3600) / 60 )) s=$(( elapsed % 60 ))
    local -r pretty="${h}h ${m}m ${s}s"
    if (( CMD_SLOW_VERBOSE )); then
      print -rP "%F{244}⏱ took %F{yellow}${pretty}%F{244} · %f${_cmd_text}"
    fi
    [[ -n "$TMUX" ]] && tmux display-message -d 8000 "⏱ ${pretty}: ${_cmd_text}" 2>/dev/null
  fi
  _cmd_text=""
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _preexec
add-zsh-hook precmd _precmd

# ─── Starship prompt (must be last) ──────
eval "$(starship init zsh)"
