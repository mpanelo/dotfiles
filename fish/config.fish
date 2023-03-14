# Homebrew
eval (/opt/homebrew/bin/brew shellenv)

# Zoxide
zoxide init fish | source

# Starship prompt
starship init fish | source


# Rust/Cargo
fish_add_path "$HOME/.cargo/bin/"

# Go
fish_add_path /usr/local/go/bin
fish_add_path "$HOME/go/bin"

alias v="nvim"
set -Ux EDITOR nvim
set -Ux VISUAL nvim

set -Ux fish_greeting

# Load configurations which should not be stored in a version control system (i.e. API keys, sensitive data, persional info, etc.)
set LOCALCFG (dirname (status --current-filename))/config.local.fish

if test -f "$LOCALCFG"
	source "$LOCALCFG"
end
