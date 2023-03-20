echo "Install Packer"
git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

echo "Symbolic link - neomvim"
ln -s $HOME/dotfiles/nvim $HOME/.config/nvim

echo "Install Rust & Cargo"
curl https://sh.rustup.rs -sSf | sh

echo "Install Lua Code Formatter"
cargo install stylua

echo "Install Go Formatter"
go install mvdan.cc/gofumpt@latest
go install golang.org/x/tools/cmd/goimports@latest

echo "Install Tree-sitter CLI"
cargo install tree-sitter-cli

#echo "Install ripgrep"
#brew install ripgrep

echo "Install fnm"
curl -fsSL https://fnm.vercel.app/install | bash

echo "Install prettierd & eslint_d"
npm install -g @fsouza/prettierd
npm install -g eslint_d
