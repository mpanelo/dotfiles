echo "Symbolic link - neomvim"
ln -s $HOME/dotfiles/nvim $HOME/.config/nvim

echo "Install Rust & Cargo"
curl https://sh.rustup.rs -sSf | sh

# nvim-treesitter
cargo install --locked tree-sitter-cli

echo "Install Go Formatter"
go install mvdan.cc/gofumpt@latest
go install golang.org/x/tools/cmd/goimports@latest

echo "Install eslint_d"
npm install -g eslint_d
