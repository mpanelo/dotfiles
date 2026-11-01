"""Application smoke checks using only existing binaries and copied plugin code."""
import json
import os
from pathlib import Path
import re
import shutil


def copy_cached_repository(harness, source, target, expected):
    actual = harness.run(["git", "-C", source, "rev-parse", "HEAD"]).stdout.strip()
    assert actual == expected, f"Cached {source.name} differs from its declared pin; no download will be attempted"
    dirty = harness.run(["git", "-C", source, "status", "--porcelain", "--untracked-files=no"]).stdout
    assert not dirty, f"Cached {source.name} has local changes; leave it untouched"
    harness.run(["git", "clone", "--local", "--no-hardlinks", "--no-checkout", source, target])
    harness.run(["git", "-C", target, "update-ref", "--no-deref", "HEAD", expected])
    files = harness.run(["git", "-C", source, "ls-files", "-z"]).stdout.split("\0")
    for relative in filter(None, files):
        original = source / relative
        copied = target / relative
        if original.is_symlink():
            # Keep upstream-relative links inside the private copy. Never create
            # a fixture link back into a live cache or outside the plugin.
            resolved = original.resolve(strict=False)
            relative_target = resolved.relative_to(source.resolve())
            copied.parent.mkdir(parents=True, exist_ok=True)
            copied.symlink_to(os.path.relpath(target / relative_target, copied.parent))
            continue
        if not original.is_file():
            continue
        copied.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, copied)


def smoke_fish(h):
    # Copy only known public plugin scripts; never copy fish_variables or history.
    origin = h.live_home / ".config/fish"
    target = h.destination / ".config/fish"
    patterns = ["functions/fisher.fish", "functions/bass.fish", "functions/__bass.py",
                "functions/_fzf_*.fish", "functions/fzf_configure_bindings.fish", "conf.d/fzf.fish",
                "completions/fisher.fish", "completions/fzf_configure_bindings.fish"]
    for pattern in patterns:
        for original in origin.glob(pattern):
            assert original.is_file() and not original.is_symlink()
            shutil.copy2(original, target / original.relative_to(origin))
    env = dict(h.env, XDG_CONFIG_HOME=str(h.destination / ".config"))
    script = '''
test "$EDITOR" = nvim; or exit 1
for name in nvd lg cat ls ll tldr curl
    abbr --query $name; or exit 1
end
functions --query fish_prompt; or exit 1
functions --query fzf_configure_bindings; or exit 1
bind ctrl-r | string match --quiet '*_fzf_search_history*'; or exit 1
bind ctrl-alt-f | string match --quiet '*_fzf_search_directory*'; or exit 1
echo DOTFILES_FISH_SMOKE_OK
'''
    result = h.run(["fish", "--interactive", "--command", script], env=env)
    assert "DOTFILES_FISH_SMOKE_OK" in result.stdout
    for versions in [h.fake_home / "Library/Application Support/fnm/node-versions",
                     h.workspace / "data/fnm/node-versions", h.fake_home / ".local/share/fnm/node-versions"]:
        assert not versions.exists() or not any(p.name.startswith("v") for p in versions.iterdir())
    h.passed("Fish starts with preserved abbreviations/fzf bindings and fnm installs no Node")


def smoke_tmux(h):
    root = h.live_home / ".config/tmux/plugins"
    for line in (h.source / "manifests/tmux-plugins.tsv").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        name, _, commit = line.split()
        copy_cached_repository(h, root / name, h.destination / ".config/tmux/plugins" / name, commit)
    env = dict(h.env, XDG_CONFIG_HOME=str(h.destination / ".config"), TMUX_TMPDIR=str(h.workspace / "tmux-runtime"))
    Path(env["TMUX_TMPDIR"]).mkdir(mode=0o700)
    socket = h.workspace / "tmux.sock"
    product = h.destination / ".config/tmux/tmux.conf"
    # Safety overrides are test-only: never restore/save even temporary sessions.
    text = product.read_text().replace("@continuum-restore 'on'", "@continuum-restore 'off'")
    text = text.replace("@continuum-save-interval '15'", "@continuum-save-interval '0'")
    config = h.workspace / "tmux-test.conf"
    # Seed the tmux 3.8 default even when testing with an older installed binary.
    config.write_text('set -g default-shell /bin/sh\n'
                      'set -g window-status-current-style underscore\n'
                      'set-environment -g HOME ' + json.dumps(str(h.fake_home)) + '\n' + text)
    helper = h.destination / ".config/tmux/has-battery.sh"
    original = helper.read_bytes()

    def tmux(*args, success=True):
        return h.run(["tmux", "-S", socket, *args], env=env, success=success)

    try:
        for battery in (0, 1):
            helper.write_text(f"#!/bin/sh\nexit {0 if battery else 1}\n")
            tmux("-f", config, "new-session", "-d", "-s", "dotfiles-test", "-x", "100", "-y", "30", "exec /bin/sleep 30")
            assert str(h.fake_home) in tmux("show-environment", "-g", "HOME").stdout
            assert tmux("show-options", "-gqv", "@show_battery").stdout.strip() == str(battery)
            assert tmux("show-options", "-gv", "base-index").stdout.strip() == "1"
            assert tmux("show-options", "-gv", "set-clipboard").stdout.strip() == "on"
            assert tmux("show-options", "-gv", "window-status-current-style").stdout.strip() == "none"
            # A single-key query displays a tmux status message on some releases;
            # listing the table consistently returns machine-readable stdout.
            prefix = tmux("list-keys", "-T", "prefix").stdout
            copy = tmux("list-keys", "-T", "copy-mode-vi").stdout
            assert re.search(r"-T prefix\s+v\s+split-window\s+-\S*h", prefix)
            assert re.search(r"-T copy-mode-vi\s+y\s+.*copy-selection", copy)
            assert not (h.destination / ".config/tmux/plugins/tmux-sessionx").exists()
            tmux("kill-server")
        h.passed("tmux preserves keys, an unadorned current window, and desktop/laptop battery behavior")
    finally:
        helper.write_bytes(original)
        h.run(["tmux", "-S", socket, "kill-server"], env=env, success=None)


def smoke_nvim(h, project_root):
    lock = json.loads((h.destination / ".config/nvim/lazy-lock.json").read_text())
    data = h.workspace / "data/nvim"
    for name, entry in lock.items():
        source = h.live_home / ".local/share/nvim/lazy" / name
        target = data / "lazy" / name
        copy_cached_repository(h, source, target, entry["commit"])
    # Copy only the native artifacts that match the declared plugin commits.
    for relative in ["telescope-fzf-native.nvim/build/libfzf.so",
                     "blink.cmp/lib/libblink_cmp_fuzzy.dylib." + lock["blink.cmp"]["commit"][:7]]:
        source = h.live_home / ".local/share/nvim/lazy" / relative
        target = data / "lazy" / relative
        assert source.is_file() and not source.is_symlink(), f"Native cache is missing: {relative}"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    parsers = data / "site/parser"
    parsers.mkdir(parents=True)
    for source in (h.live_home / ".local/share/nvim/site/parser").glob("*.so"):
        assert not source.is_symlink()
        shutil.copy2(source, parsers / source.name)
    queries = data / "lazy/nvim-treesitter/runtime/queries"
    if queries.is_dir():
        shutil.copytree(queries, data / "site/queries")
    env = dict(h.env, XDG_CONFIG_HOME=str(h.destination / ".config"), DOTFILES_VERIFY_ONLY="1")
    startup = "lua vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function() vim.schedule(function() dofile(" + json.dumps(str(project_root / "tests/smoke-nvim.lua")) + ") end) end })"
    capture = "lua _G.dotfiles_startup_errors = {}; local notify = vim.notify; vim.notify = function(msg, level, opts) if level == vim.log.levels.ERROR then table.insert(_G.dotfiles_startup_errors, tostring(msg)) end; return notify(msg, level, opts) end"
    result = h.run(["nvim", "--headless", "-i", "NONE", "-n", "--cmd", capture, "-c", startup], env=env)
    assert "DOTFILES_NVIM_SMOKE_OK" in result.stdout
    h.passed("Neovim loads copied pinned plugins, parsers, native matchers, keymaps and StyLua")
    missing = [tool for tool in ("lua-language-server", "basedpyright-langserver", "gopls", "goimports", "gofumpt", "rust-analyzer", "ruff")
               if shutil.which(tool, path=env["PATH"]) is None]
    print("Not provisioned/tested here: language-server attachment; missing direct tools:", ", ".join(missing) or "none", flush=True)


def smoke(harness, project_root):
    smoke_fish(harness)
    smoke_tmux(harness)
    smoke_nvim(harness, project_root)
