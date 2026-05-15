echo "Install Packer"
git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

echo "Symbolic link - neomvim"
ln -s $HOME/dotfiles/nvim $HOME/.config/nvim

echo "Install Rust & Cargo"
curl https://sh.rustup.rs -sSf | sh

# nvim-treesitter
cargo install --locked tree-sitter-cli

echo "Install Go Formatter"
go install mvdan.cc/gofumpt@latest
go install golang.org/x/tools/cmd/goimports@latest

echo "Install prettierd & eslint_d"
npm install -g @fsouza/prettierd
npm install -g eslint_d
