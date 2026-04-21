# Homebrew
eval (/opt/homebrew/bin/brew shellenv)

fish_add_path "$HOME/.cargo/bin/", "$HOME/go/bin"
#fish_add_path "/Applications/Alacritty.app/Contents/MacOS"

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx fish_greeting

abbr lg "lazygit"
#abbr tn "tmux new -s"
#abbr fs "tmux ls -F '#{session_name}' | fzf-tmux -p | xargs tmux switch -t"

starship init fish | source
zoxide init fish | source

# This command will install keybindings for fishshell, but we do not want
# fzf-history-widget and fzf-file-widget because fzf.fish provides
# a better history and file search interface.
fzf --fish | source
bind --erase -- \ct
bind --erase --mode insert -- \ct
bind --erase -- \cr
bind --erase --mode insert -- \cr

direnv hook fish | source
