#!/bin/zsh

alias vi=nvim
alias vim=nvim
alias cd=z
alias r=ranger

# asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"


# Load .env if it exists and is valid
if [[ -f "$HOME/dotfiles/.env" ]]; then
  set -o allexport
  source "$HOME/dotfiles/.env" || echo "Warning: Failed to source .env"
  set +o allexport
fi

# shorthand commands
alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias la="ls -la"
alias lzg="lazygit"
alias lzd="lazydocker"

# starship and zoxide (check they exist first)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# custom binaries
export PATH="$HOME/dotfiles/.local/share/bin:$PATH"
