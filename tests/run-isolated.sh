#!/bin/bash
# Optional temporary test-tool download. Never installs into Homebrew or HOME.
set -euo pipefail
root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
binary=''
download=0
smoke=0
keep=0
while (($#)); do
    case $1 in
        --chezmoi) [[ $# -ge 2 ]] || exit 2; binary=$2; shift 2 ;;
        --download-chezmoi) download=1; shift ;;
        --smoke) smoke=1; shift ;;
        --keep-workspace) keep=1; shift ;;
        --help|-h)
            printf '%s\n' 'Usage: tests/run-isolated.sh [--chezmoi PATH | --download-chezmoi] [--smoke] [--keep-workspace]' \
                'Downloads, if requested, are verified and stored temporarily. All applies target temporary fixtures.'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
if ((download)); then
    [[ -z "$binary" && $(uname -s) == Darwin && $(uname -m) == arm64 ]] || {
        printf '%s\n' 'Temporary download supports native Apple Silicon; otherwise supply --chezmoi PATH.' >&2; exit 2
    }
    temporary=$(mktemp -d -t dotfiles-test-tool)
    trap 'rm -rf "$temporary"' EXIT
    release=2.73.3
    # Official v2.73.3 checksums, verified before this pin was recorded.
    expected=ec2d0005f369c912ee9891a26c30d65dc0eda51708f06948e5f7a43db69e1aa7
    curl -q --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        "https://github.com/twpayne/chezmoi/releases/download/v$release/chezmoi_${release}_darwin_arm64.tar.gz" \
        -o "$temporary/archive.tar.gz"
    [[ $(shasum -a 256 "$temporary/archive.tar.gz" | awk '{print $1}') == "$expected" ]] || {
        printf '%s\n' 'chezmoi checksum mismatch; refusing to extract or run.' >&2; exit 1
    }
    tar -xzf "$temporary/archive.tar.gz" -C "$temporary" chezmoi
    binary="$temporary/chezmoi"
fi
if [[ -z "$binary" ]]; then binary=$(command -v chezmoi || true); fi
[[ -n "$binary" ]] || {
    printf '%s\n' 'Supply --chezmoi PATH or explicitly request --download-chezmoi.' >&2; exit 2
}
command=(python3 "$root/tests/test_chezmoi_integration.py" --chezmoi "$binary")
if ((smoke)); then command+=(--smoke); fi
if ((keep)); then command+=(--keep-workspace); fi
"${command[@]}"
