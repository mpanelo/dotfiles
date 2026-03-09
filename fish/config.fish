# Homebrew
eval (/opt/homebrew/bin/brew shellenv)

fzf --fish | source

# Zoxide
zoxide init fish | source

# Starship prompt
starship init fish | source

# Rust/Cargo
fish_add_path "$HOME/.cargo/bin/", "$HOME/go/bin"

#fish_add_path "/Applications/Alacritty.app/Contents/MacOS"

# Go
fish_add_path /usr/local/go/bin
fish_add_path "$HOME/go/bin"

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx fish_greeting

abbr lg "lazygit"
#abbr tn "tmux new -s"
#abbr fs "tmux ls -F '#{session_name}' | fzf-tmux -p | xargs tmux switch -t"
