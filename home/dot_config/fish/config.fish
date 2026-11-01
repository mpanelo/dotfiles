set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx fish_greeting
set -gx LESS -R
set -gx SHELL (command -s fish)

if status is-interactive
    abbr nvd "nvim -c 'DiffviewOpen'"
    abbr lg "lazygit"
    abbr cat "bat"
    abbr ls "eza"
    abbr tldr "tldr --color always"
    abbr curl "http"
    abbr ll "eza -l"

    command -q starship; and starship init fish | source
    command -q zoxide; and zoxide init fish | source

    # Preserve fzf.fish's history and directory bindings.
    set -gx FZF_CTRL_R_COMMAND ""
    set -gx FZF_CTRL_T_COMMAND ""
    command -q fzf; and fzf --fish | source
    command -q direnv; and direnv hook fish | source
end
