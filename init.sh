#!/bin/zsh

# Aliases
alias vi=nvim
alias vim=nvim
alias cd=z
# Yazi wrapper: changes cwd on exit
function r() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ASDF
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export EDITOR=vim

# Load .env if it exists and is valid
if [[ -f "$HOME/dotfiles/.env" ]]; then
  set -o allexport
  source "$HOME/dotfiles/.env" || echo "Warning: Failed to source .env"
  set +o allexport
fi

# Shorthand Commands
alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias la="ls -la"
alias lzg="lazygit"
alias lzd="lazydocker"
# btop writes its config to $XDG_CONFIG_HOME on exit via rename(), which
# severs stow symlinks. Point btop directly at the file in dotfiles so its
# rewrites land in the tracked copy — no symlink in between to break.
alias btop="btop --config $HOME/dotfiles/.config/btop/btop.conf"

# History Settings
HISTFILE=~/.zsh_history # Where to store history
HISTSIZE=10000          # Number of history entries to keep in memory for current session
SAVEHIST=10000          # Number of history entries to save to HISTFILE

# Append history to the history file, don't overwrite it
setopt APPEND_HISTORY

# !!! CRUCIAL FOR YOUR REQUEST !!!
# Do NOT share history live between sessions.
# Each session reads the HISTFILE on startup and writes its new history on exit.
unsetopt SHARE_HISTORY

# Do NOT append history to the file incrementally (live).
# New commands are only written to the HISTFILE when the shell exits.
unsetopt INC_APPEND_HISTORY

# Don't save duplicate commands in the history file
setopt HIST_IGNORE_DUPS

# Remove older duplicate entries first when pruning history
setopt HIST_EXPIRE_DUPS_FIRST

# Don't save commands starting with a space
setopt HIST_IGNORE_SPACE

# Remove extra blanks from history lines
setopt HIST_REDUCE_BLANKS

# Use fcntl locking to prevent history corruption when multiple shells write on exit
setopt HIST_FCNTL_LOCK

bindkey '^[[A' history-beginning-search-backward # Up arrow
bindkey '^[[B' history-beginning-search-forward  # Down arrow

# Starship and Zoxide (check they exist first)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# custom binaries
export PATH="$HOME/dotfiles/.local/share/bin:$PATH"
export PATH="/home/kalu/.local/bin:$PATH"

alias claudee="claude --dangerously-skip-permissions"

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# direnv setup
eval "$(direnv hook zsh)"

# Per-user zsh completions (cliq, etc.). zsh's default fpath omits this
# XDG dir, so add it and (re-)init the completion system. Runs before
# ~/.bun/_bun's compinit, which then no-ops since compinit is already loaded.
fpath=("$HOME/.local/share/zsh/site-functions" $fpath)
autoload -Uz compinit && compinit

