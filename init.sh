alias vi=nvim
alias vim=nvim
alias cd=z
alias r=ranger

# shorthand commands
alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias la="ls -la"
alias lzg="lazygit"
alias lzd="lazydocker"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# custom binaries
export PATH=$PATH:$HOME/.local/share/bin

set -o allexport
source $HOME/dotfiles/.env
set +o allexport
