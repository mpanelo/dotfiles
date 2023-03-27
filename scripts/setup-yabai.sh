#!/usr/bin/env sh

ln -s $HOME/dotfiles/yabai $HOME/.config/yabai
ln -s $HOME/dotfiles/skhd $HOME/.config/skhd

# brew services start yabai
# brew services start skhd

# You may need to restart yabai/skhd when prompted to allow accessibility
# brew services restart yabai
# brew services restart skhd
