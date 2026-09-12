#!/usr/bin/env bash

set -euo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	bold=$'\033[1m'
	cyan=$'\033[36m'
	dim=$'\033[2m'
	reset=$'\033[0m'
else
	bold=''
	cyan=''
	dim=''
	reset=''
fi

for command in git tmux; do
	if ! command -v "$command" >/dev/null 2>&1; then
		echo "tmux setup: missing required command: $command" >&2
		exit 1
	fi
done

script_dir="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_conf="$script_dir/tmux.conf"
battery_check="$script_dir/has-battery.sh"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
tmux_config_dir="$config_home/tmux"
tmux_conf="$tmux_config_dir/tmux.conf"
battery_check_target="$tmux_config_dir/has-battery.sh"

for source_file in "$source_conf" "$battery_check"; do
	if [ ! -f "$source_file" ]; then
		echo "tmux setup: source file not found: $source_file" >&2
		exit 1
	fi
done

if [ -L "$tmux_config_dir" ]; then
	echo "tmux setup: refusing to use symlinked config directory: $tmux_config_dir" >&2
	echo "Only tmux.conf should be symlinked into the XDG directory." >&2
	echo "Move the directory symlink aside, then rerun this script." >&2
	exit 1
fi

if [ ! -e "$tmux_conf" ] && [ ! -L "$tmux_conf" ] && [ -f "$HOME/.tmux.conf" ]; then
	echo "tmux setup: refusing to shadow existing $HOME/.tmux.conf" >&2
	echo "Move it or remove it before installing the XDG config: $tmux_conf" >&2
	exit 1
fi

mkdir -p "$tmux_config_dir"
if [ -e "$tmux_conf" ] || [ -L "$tmux_conf" ]; then
	if [ ! "$tmux_conf" -ef "$source_conf" ]; then
		echo "tmux setup: refusing to overwrite existing config: $tmux_conf" >&2
		exit 1
	fi
else
	ln -s "$source_conf" "$tmux_conf"
	printf '%sLinked tmux.conf at %s%s\n' "$cyan" "$tmux_conf" "$reset"
fi

if [ -e "$battery_check_target" ] || [ -L "$battery_check_target" ]; then
	if [ ! "$battery_check_target" -ef "$battery_check" ]; then
		echo "tmux setup: refusing to overwrite existing helper: $battery_check_target" >&2
		exit 1
	fi
else
	ln -s "$battery_check" "$battery_check_target"
fi

tmux_conf_display="$tmux_conf"
if [[ "$tmux_conf_display" == "$HOME"/* ]]; then
	# This tilde is intentionally literal: it is printed for the user to paste.
	# shellcheck disable=SC2088
	tmux_conf_display='~/'
	tmux_conf_display+="${tmux_conf#"$HOME"/}"
fi

plugin_root="$tmux_config_dir/plugins"
mkdir -p "$plugin_root"

tmux_server_running=0
if [ -n "${TMUX:-}" ] || tmux list-sessions >/dev/null 2>&1; then
	tmux_server_running=1
fi

tmux_server_started_by_setup=0
cleanup() {
	if (( tmux_server_started_by_setup )); then
		tmux kill-server >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

if [ ! -d "$plugin_root/tpm" ]; then
	printf '%sInstalling TPM...%s\n' "$cyan" "$reset"
	git clone --quiet --depth 1 https://github.com/tmux-plugins/tpm "$plugin_root/tpm"
fi

# Let TPM detect the plugin directory from the XDG-linked config. If a server
# was already running, clear a stale value left by an older configuration.
if (( tmux_server_running )); then
	tmux set-environment -gu TMUX_PLUGIN_MANAGER_PATH
else
	# TPM needs a server for its environment, but the config itself will be
	# loaded by the user's next tmux server. Use a temporary empty session here.
	env -u TMUX -u TMUX_PLUGIN_MANAGER_PATH tmux -f /dev/null \
		new-session -d -s "tmux-setup-$$"
	tmux_server_started_by_setup=1
fi

env -u TMUX_PLUGIN_MANAGER_PATH "$plugin_root/tpm/tpm" >/dev/null

printf '%sInstalling/checking TPM plugins...%s\n' "$cyan" "$reset"
"$plugin_root/tpm/bin/install_plugins" >/dev/null

printf '\n%sTmux plugins installed.%s\n' "$bold" "$reset"
if (( tmux_server_running )); then
	printf '\n%sA tmux server is running.%s Reload with:\n' "$bold" "$reset"
	printf '  %s%s tmux source-file %s%s\n' "$cyan" "$bold" "$tmux_conf_display" "$reset"
else
	printf '%sNo tmux server is running;%s the configuration will load on the next start.\n' "$dim" "$reset"
fi
