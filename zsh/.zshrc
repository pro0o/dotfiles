# -----------------------------
# Powerlevel10k instant prompt
# -----------------------------
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------
# Zinit plugin manager
# -----------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "$ZINIT_HOME/zinit.zsh"

# plugins
zinit light romkatv/powerlevel10k
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
# zinit light agkozak/zsh-z  # replaced by zoxide

# prompt config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# -----------------------------
# Keybindings
# -----------------------------
bindkey '^f' autosuggest-accept

# Copy last command + output to clipboard (Ctrl+Y)
# Note: re-executes the last command to capture its output
autoload -Uz add-zsh-hook
typeset -g __LAST_CMD=""
_save_last_cmd() { __LAST_CMD="$1"; }
add-zsh-hook preexec _save_last_cmd

_copy_cmd_output() {
    if [[ -z "$__LAST_CMD" ]]; then
        zle -M "No previous command to copy"
        return
    fi
    # Block destructive commands from re-execution
    local first="${__LAST_CMD%% *}"
    local check="$first"
    [[ "$first" == "sudo" ]] && check="${__LAST_CMD#sudo }" && check="${check%% *}"
    local blocked=(rm mv cp dd mkfs chmod chown kill reboot shutdown systemctl rmdir shred truncate)
    if (( ${blocked[(Ie)$check]} )); then
        # Copy just the command without output
        printf '> %s\n[output not captured — destructive command]' "$__LAST_CMD" | xclip -selection clipboard
        zle -M "Copied command only (skipped re-exec: $check)"
        return
    fi
    local output
    output=$(eval "$__LAST_CMD" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    printf '> %s\n%s' "$__LAST_CMD" "$output" | xclip -selection clipboard
    zle -M "Copied to clipboard: $__LAST_CMD"
}
zle -N _copy_cmd_output
bindkey '^X^X' _copy_cmd_output

# -----------------------------
# History
# -----------------------------
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_find_no_dups

# -----------------------------
# Completion styling
# -----------------------------
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# Ctrl + Left Arrow → backward word
bindkey "^[[1;5D" backward-word

# Ctrl + Right Arrow → forward word
bindkey "^[[1;5C" forward-word

# -----------------------------
# Aliases
# -----------------------------
alias ls='ls --color'
alias lg='lazygit'
alias y='yazi'

# -----------------------------
# Clipmenu (clipboard manager)
# -----------------------------
export CM_MAX_CLIPS=10
export CM_DIR="/tmp/clipmenu-$USER"

# -----------------------------
# Paths
# -----------------------------
export PATH="$HOME/.fly/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# -----------------------------
# NVM (lazy load)
# -----------------------------
export NVM_DIR="$HOME/.nvm"

load-nvm() {
  unset -f node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
}

node() { load-nvm; node "$@"; }
npm() { load-nvm; npm "$@"; }
npx() { load-nvm; npx "$@"; }

# -----------------------------
# Shell integrations
# -----------------------------
# completion system
autoload -Uz compinit
compinit

#fzf integration
eval "$(fzf --zsh)"

# zoxide (smarter cd)
eval "$(zoxide init zsh)"

# Angular completion (lazy)
if command -v ng >/dev/null; then
  source <(ng completion script)
fi

# bun completion
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
