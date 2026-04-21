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
fzf --fish | source
direnv hook fish | source
