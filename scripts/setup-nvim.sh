echo "Install Packer"
git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

echo "Symbolic link - neomvim"
ln -s $HOME/dotfiles/nvim $HOME/.config/nvim

echo "Install Rust & Cargo"
curl https://sh.rustup.rs -sSf | sh

echo "Install Lua Code Formatter"
cargo install stylua

echo "Install Tree-sitter CLI"
cargo install tree-sitter-cli

echo "Install ripgrep"
brew install ripgrep
