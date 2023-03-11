# Homebrew
eval (/opt/homebrew/bin/brew shellenv)

alias vim="nvim"

# Rust/Cargo
fish_add_path "$HOME/.cargo/bin/"

# Go
fish_add_path /usr/local/go/bin

zoxide init fish | source

starship init fish | source

# Load configurations which should not be stored in a version control system (i.e. API keys, sensitive data, persional info, etc.)
set LOCALCFG (dirname (status --current-filename))/config.local.fish

if test -f "$LOCALCFG"
	source "$LOCALCFG"
end
