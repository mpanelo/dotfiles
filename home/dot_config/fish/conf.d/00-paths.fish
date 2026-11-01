# conf.d runs before config.fish and plugin initialization.
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv fish | source
    fish_add_path --global /opt/homebrew/opt/ssh-copy-id/bin
else if test -x /usr/local/bin/brew
    /usr/local/bin/brew shellenv fish | source
    fish_add_path --global /usr/local/opt/ssh-copy-id/bin
end

# Global scope avoids writing machine paths into universal variables.
fish_add_path --global --move "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" "$HOME/bin"
