# Tmux setup

This directory contains the tmux configuration and the scripts used to install
or deploy it:

- [`tmux.conf`](tmux.conf): the tmux configuration.
- [`has-battery.sh`](has-battery.sh): detects whether the current machine has a battery.
- [`setup.sh`](setup.sh): installs the configuration and TPM locally.
- [`deploy.sh`](deploy.sh): copies the tmux source files to a remote machine.

## Local setup

From the dotfiles repository, run:

```sh
./tmux/setup.sh
```

The script:

1. Creates `${XDG_CONFIG_HOME:-$HOME/.config}/tmux`.
2. Symlinks `tmux.conf` and `has-battery.sh` into that directory.
3. Installs TPM and all configured plugins under the XDG tmux directory.
4. Uses TPM's XDG autodetection instead of setting `TMUX_PLUGIN_MANAGER_PATH` in
   `tmux.conf`.

The setup requires `git` and `tmux`. Plugin installation requires network access
to GitHub.

If a tmux server is already running, setup prints a reload command. Otherwise,
the configuration will be loaded the next time tmux starts. Reload manually with:

```sh
tmux source-file "$HOME/.config/tmux/tmux.conf"
tmux refresh-client -S
```

The setup script refuses to use a symlinked `~/.config/tmux` directory. Only the
individual configuration files should be symlinked. This prevents plugins from
being installed inside the dotfiles repository.

## Remote setup

Deploy the tmux source files to a remote host with:

```sh
./tmux/deploy.sh user@example.com
```

By default, files are copied to `~/dotfiles/tmux/` on the remote host. A
different remote dotfiles directory can be supplied:

```sh
./tmux/deploy.sh user@example.com ~/config-repo
```

The deploy script uses `ssh` and `tar`, preserves executable permissions, and
does not copy local plugin checkouts. This is intentional: plugins should be
installed for the remote OS by the remote setup script.

After connecting to the remote host:

```sh
ssh user@example.com
cd ~/dotfiles
./tmux/setup.sh
```

The remote machine needs `git` and `tmux`, plus network access for plugin
installation.

## Configuration details

### XDG and TPM paths

The configuration sets a tmux environment variable named `TMUX_CONFIG_DIR`:

```tmux
set-environment -g TMUX_CONFIG_DIR "$HOME/.config/tmux"
```

When `XDG_CONFIG_HOME` is set, it uses `$XDG_CONFIG_HOME/tmux` instead. TPM
then detects its plugin directory from the presence of the XDG `tmux.conf`.
There is deliberately no `TMUX_PLUGIN_MANAGER_PATH` setting in this config.

### Plugins and status line

The Catppuccin plugin is installed from
[`mpanelo/catppuccin-tmux`](https://github.com/mpanelo/catppuccin-tmux).
The configuration loads Catppuccin before defining its status modules, then
loads TPM last. This order matters:

- Catppuccin defines the module styles.
- `tmux-battery` replaces its battery interpolations.
- `tmux-continuum` replaces `#{continuum_status}`.

The Catppuccin fork does not provide a Continuum module, so this configuration
defines a small local save-status module with a save icon. The battery module
is appended only when `has-battery.sh` detects battery hardware. Servers and
desktop machines therefore show Continuum status without a meaningless battery
indicator.

The status icons require a terminal font with the relevant Nerd Font glyphs.

### Intentional defaults

- Windows and panes use one-based indexes.
- Copy mode uses vi-style bindings.
- `prefix + x` asks for confirmation before killing a pane.
- Clipboard integration is enabled with `set-clipboard on`.
- Mouse support is enabled.
- No default shell is forced; tmux uses the host machine's shell.
- There is no previous-session binding on `C-b`, and no `R` or `g` bindings.

## Troubleshooting

Check the paths detected by the running tmux server:

```sh
tmux show-environment -g TMUX_CONFIG_DIR
tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH
```

The plugin path should be inside the XDG tmux directory, for example:

```text
TMUX_PLUGIN_MANAGER_PATH=/Users/example/.config/tmux/plugins/
```

If plugins are missing, rerun `./tmux/setup.sh`; TPM's interactive install key
binding is not required for initial setup.
