#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/bootstrap/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=scripts/bootstrap/alacritty.sh
source "$REPO_ROOT/scripts/bootstrap/alacritty.sh"

destination=$HOME
files_only=0
quiet=0
while (($#)); do
    case $1 in
        --destination) (($# >= 2)) || die '--destination needs an absolute directory.'; destination=$2; shift 2 ;;
        --files-only) files_only=1; shift ;;
        --quiet) quiet=1; shift ;;
        *) die "Unknown preflight argument: $1" ;;
    esac
done
[[ -d "$destination" && "$destination" == /* ]] || die 'Destination must be an existing absolute directory.'
if ((!quiet)); then
    log 'Checking for installation conflicts (no installation or configuration changes)'
    printf 'Destination: %s\n' "$destination"
fi
# Provisioning stages still run every guard, but only report conflicts/errors.
report() { if ((!quiet)); then printf '  %s  %s\n' "$1" "$2"; fi; }
if ((files_only)); then
    report INFO 'Destination-only mode: platform, app/font and prerequisite checks are skipped.'
else
    require_macos
    report OK "Platform and directory settings: macOS $(uname -m); Homebrew prefix $BREW_PREFIX."
fi

# New source files must enter the conflict/backup inventory before deployment.
source_count=0
while IFS= read -r source_path; do
    source_relative=${source_path#"$REPO_ROOT/home"/}
    case "$source_relative" in .chezmoi*|run_*) continue ;; esac
    awk -v source="$source_relative" '$2 == source {found=1} END {exit !found}' "$REPO_ROOT/manifests/config-files.tsv" ||
        die "Source file is missing from the safety inventory: $source_relative"
    source_count=$((source_count + 1))
done < <(find "$REPO_ROOT/home" -type f | LC_ALL=C sort)
report OK "Repository inventory: $source_count configuration files covered by conflict checks and backups."

conflicts=0
conflict() { printf 'CONFLICT: %s\n' "$*" >&2; conflicts=$((conflicts + 1)); }
baseline="$destination/.local/state/dotfiles/managed.sha256"
safe_path "$destination" '.local/state/dotfiles/managed.sha256' || die 'Unsafe state directory or ownership manifest.'

absent=0
matching=0
managed=0
checked=0
while read -r relative source_file; do
    [[ -n "$relative" && "$relative" != \#* ]] || continue
    checked=$((checked + 1))
    target="$destination/$relative"
    if ! safe_path "$destination" "$relative"; then
        conflict "$relative has a symlink or non-directory parent; leave it intact and use the migration procedure."
        continue
    fi
    if [[ ! -e "$target" ]]; then absent=$((absent + 1)); continue; fi
    if [[ ! -f "$target" ]]; then conflict "$relative is not a regular file."; continue; fi
    actual=$(sha_file "$target")
    previous=''
    if [[ -f "$baseline" ]]; then previous=$(awk -v path="$relative" '$2 == path {print $1; exit}' "$baseline"); fi
    if [[ -n "$previous" && "$actual" == "$previous" ]]; then
        managed=$((managed + 1))
        continue
    fi
    if [[ "$source_file" == *.tmpl ]] && ! command -v chezmoi >/dev/null 2>&1; then
        conflict "$relative already exists; chezmoi is needed to render and compare this template safely."
        continue
    fi
    # Rendering desired content does not apply files or execute run scripts.
    desired=$(desired_hash "$destination" "$relative" "$source_file")
    if [[ "$actual" == "$desired" ]]; then matching=$((matching + 1))
    else conflict "$relative differs from both the desired content and the last applied version."
    fi
done < "$REPO_ROOT/manifests/config-files.tsv"
status=OK
((conflicts == 0)) || status=FAIL
report "$status" "Configuration files: $checked checked; $absent absent, $matching matching, $managed unchanged since last apply, $conflicts conflicts."

before_runtime=$conflicts
runtime_count=0
for relative in .local/bin .local/share/uv .local/share/uv/tools/basedpyright .local/share/uv/tools/ruff .local/share/nvim .local/share/dotfiles go/bin .cargo/bin .rustup .config/tmux/plugins .config/chezmoi Applications .terminfo; do
    runtime_count=$((runtime_count + 1))
    safe_path "$destination" "$relative" || conflict "Unsafe runtime directory: $relative"
    [[ ! -e "$destination/$relative" || -d "$destination/$relative" ]] || conflict "Runtime path is not a directory: $relative"
done
status=OK
((conflicts == before_runtime)) || status=FAIL
report "$status" "Runtime/state paths: $runtime_count checked for symlinks and non-directory parents."
if [[ -e "$destination/.tmux.conf" || -L "$destination/.tmux.conf" ]]; then
    conflict 'Existing ~/.tmux.conf could shadow the XDG configuration.'
else report OK 'No legacy ~/.tmux.conf that would shadow the managed tmux configuration.'
fi

if ((!files_only)); then
    # Stop before installing packages over manually installed cask artifacts.
    if [[ -e /Applications/Alacritty.app || -L /Applications/Alacritty.app ]]; then
        if [[ -d "$BREW_PREFIX/Caskroom/alacritty" ]]; then
            report OK 'Alacritty: existing Homebrew application will be kept.'
        else conflict 'Alacritty.app in /Applications is unmanaged. Review it before provisioning.'
        fi
    fi
    if ! safe_path "$HOME" 'Applications/Alacritty.app' ||
        ! safe_path "$HOME" '.local/state/dotfiles/alacritty.sha256'; then
        conflict 'Unsafe Alacritty application directory or ownership record.'
    elif [[ -e "$HOME/Applications/Alacritty.app" ]]; then
        if alacritty_is_managed; then
            report OK 'Alacritty: user application matches its recorded contents.'
        else conflict "$HOME/Applications/Alacritty.app is unowned or modified; it will not be overwritten."
        fi
    else
        report OK 'Alacritty: user application destination is available for the pinned upstream release.'
    fi
    if [[ -e "$HOME/.local/bin/alacritty" || -L "$HOME/.local/bin/alacritty" ]]; then
        if [[ $(alacritty_app) != /Applications/Alacritty.app ]] &&
            [[ ! -L "$HOME/.local/bin/alacritty" || $(readlink "$HOME/.local/bin/alacritty") != "$HOME/Applications/Alacritty.app/Contents/MacOS/alacritty" ]]; then
            conflict "$HOME/.local/bin/alacritty is not the managed application link."
        fi
    fi
    if [[ ! -d "$BREW_PREFIX/Caskroom/font-jetbrains-mono-nerd-font" ]]; then
        before_fonts=$conflicts
        for font_dir in "$HOME/Library/Fonts" /Library/Fonts; do
            for font in "$font_dir"/*JetBrains*"Nerd"*; do
                [[ -e "$font" ]] || continue
                conflict 'JetBrains Nerd Fonts are unmanaged. Review identical-artifact adoption or a backed-up handoff.'
                break 2
            done
        done
        if ((conflicts == before_fonts)); then
            report OK 'Nerd Font: no unmanaged JetBrains Nerd Fonts to conflict with installation.'
        fi
    else
        report OK 'Nerd Font: Homebrew cask is already registered.'
    fi
    if xcode-select -p >/dev/null 2>&1; then
        report INFO 'Command Line Tools: developer directory is configured.'
    else report INFO 'Command Line Tools: missing; bootstrap will request installation.'
    fi
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        report INFO "Homebrew: present at $BREW_PREFIX/bin/brew."
    else report INFO "Homebrew: missing; bootstrap will install it at $BREW_PREFIX."
    fi
    if [[ -x "$BREW_PREFIX/bin/chezmoi" ]]; then
        report INFO 'chezmoi: present in the Homebrew prefix.'
    else report INFO 'chezmoi: missing from the Homebrew prefix; bootstrap will install it.'
    fi
fi

if ((!quiet)); then
    printf '\nNot checked: network access, administrator authentication, tool versions,\n'
    printf 'language-server behavior, or terminal/font rendering.\n'
fi
((conflicts == 0)) || die "Installation blocked by $conflicts conflict(s). No installation or configuration changes were made. See docs/recovery.md."
if ((!quiet)); then
    log 'Installation conflict check passed: no blocking conflicts were found.'
    printf 'Missing tools are expected on a clean Mac; this is not a completed provisioning check.\n'
    printf 'No software was installed and no destination configuration files were changed.\n'
fi
