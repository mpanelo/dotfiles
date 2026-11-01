#!/usr/bin/env python3
"""Exercise real chezmoi in a disposable source, home, destination and state.

Does not download/install tools. Supply an existing chezmoi executable. Every
apply targets a generated temporary directory; production provisioning is denied.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def snapshot(tree):
    result = {}
    for path in sorted(tree.rglob("*")):
        info = path.lstat()
        relative = str(path.relative_to(tree))
        if path.is_symlink():
            value = os.readlink(path)
        elif path.is_file():
            value = hashlib.sha256(path.read_bytes()).hexdigest()
        else:
            value = "directory"
        result[relative] = (stat.S_IMODE(info.st_mode), info.st_mtime_ns, value)
    return result


def live_metadata(home):
    # Metadata only: never read universal variables, credentials or private state.
    relative_paths = [line.split()[0] for line in (ROOT / "manifests/config-files.tsv").read_text().splitlines()
                      if line and not line.startswith("#")]
    relative_paths += [".config/fish", ".config/alacritty", ".config/nvim", ".config/tmux",
                       ".config/chezmoi", ".cache/chezmoi", ".local/share/chezmoi"]
    result = {}
    for relative in relative_paths:
        path = home / relative
        try:
            info = path.lstat()
            result[relative] = (info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns,
                                os.readlink(path) if path.is_symlink() else None)
        except FileNotFoundError:
            result[relative] = None
    return result


class Harness:
    def __init__(self, workspace, executable):
        self.workspace = workspace.resolve()
        self.executable = executable.resolve()
        self.live_home = Path.home()
        self.source = self.workspace / "source"
        self.destination = self.workspace / "destination"
        self.fake_home = self.workspace / "user-home"
        for path in (self.source, self.destination, self.fake_home, self.workspace / "tmp"):
            path.mkdir()
        self.config = self.workspace / "config/chezmoi/chezmoi.toml"
        self.config.parent.mkdir(parents=True)
        # Deliberately do not inherit tokens, shell hooks, proxy credentials,
        # app configuration, or language-manager environment variables.
        self.env = {
            "HOME": str(self.fake_home),
            "PATH": os.pathsep.join([str(self.executable.parent), "/opt/homebrew/bin", "/usr/local/bin",
                                     "/usr/local/go/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]),
            "XDG_CONFIG_HOME": str(self.workspace / "config"),
            "XDG_CACHE_HOME": str(self.workspace / "cache"),
            "XDG_DATA_HOME": str(self.workspace / "data"),
            "XDG_STATE_HOME": str(self.workspace / "state"),
            "TMPDIR": str(self.workspace / "tmp"),
            "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0",
            "GIT_OPTIONAL_LOCKS": "0", "GIT_ALLOW_PROTOCOL": "file",
            "DOTFILES_ISOLATED_TEST": "1", "GOTOOLCHAIN": "local", "RUSTUP_AUTO_INSTALL": "0",
            "TERM": "xterm-256color", "LANG": "en_US.UTF-8", "NO_COLOR": "1",
        }
        for name in ("home", "manifests", "scripts/bootstrap"):
            shutil.copytree(ROOT / name, self.source / name)
        shutil.copyfile(ROOT / ".chezmoiroot", self.source / ".chezmoiroot")
        self.run(["git", "init", "--quiet", str(self.source)])
        self.checks = []
        self.command_log = self.workspace / "commands.log"

    def run(self, command, *, env=None, data=None, success=True):
        result = subprocess.run(list(map(str, command)), env=env or self.env, input=data,
                                capture_output=True, text=True, cwd=self.workspace, timeout=90)
        if hasattr(self, "command_log"):
            with self.command_log.open("a") as stream:
                stream.write("$ " + " ".join(map(str, command)) + "\n")
                stream.write(result.stdout + result.stderr + "\n")
        if success and result.returncode:
            raise AssertionError(f"Command failed ({result.returncode}): {command}\n{result.stdout}{result.stderr}")
        if success is False and not result.returncode:
            raise AssertionError(f"Unsafe operation unexpectedly succeeded: {command}")
        return result

    def chez(self, *args, **kwargs):
        return self.run([self.executable, "--config", self.config,
                         "--cache", self.workspace / "cache/chezmoi",
                         "--persistent-state", self.workspace / "state/chezmoi.boltdb",
                         "--source", self.source, "--working-tree", self.source,
                         "--destination", self.destination, "--no-tty", "--no-pager",
                         "--color=false", *args], **kwargs)

    def passed(self, name):
        self.checks.append(name)
        print("PASS:", name, flush=True)

    def deployment_checks(self):
        self.chez("init", "--config-path", self.config, "--data=false")
        assert self.config.is_file()
        self.passed("initialization writes only the isolated configuration")

        context = self.chez("execute-template", data="{{ .chezmoi.homeDir }}\n{{ .chezmoi.destDir }}\n{{ .chezmoi.workingTree }}\n").stdout.splitlines()
        assert Path(context[0]).resolve() != self.destination
        assert Path(context[1]).resolve() == self.destination
        assert Path(context[2]).resolve() == self.source
        self.passed("real template context distinguishes home, destination and source")

        for path in sorted((self.source / "home").glob("run_*.tmpl")):
            rendered = self.chez("execute-template", data=path.read_text()).stdout
            self.run(["/bin/bash", "-n"], data=rendered)
            assert "reconcile.sh" not in rendered, f"Installer in isolated hook: {path.name}"
            if "preflight" in path.name:
                assert "--files-only --destination" in rendered
                assert str(self.destination) in rendered
            else:
                assert [line for line in rendered.splitlines() if line and not line.startswith("#")] == ["set -euo pipefail", "exit 0"]
        self.passed("all provisioning hooks render as no-ops for this destination")

        denied = self.run(["/bin/bash", self.source / "scripts/bootstrap/reconcile.sh", "packages"], success=False)
        assert "Provisioning is disabled" in denied.stderr
        self.passed("independent guard refuses installers even if called directly")

        empty = snapshot(self.destination)
        self.chez("--dry-run", "apply")
        assert snapshot(self.destination) == empty
        self.passed("real dry-run leaves destination unchanged")

        self.chez("apply")
        declared = [line.split()[0] for line in (self.source / "manifests/config-files.tsv").read_text().splitlines()
                    if line and not line.startswith("#")]
        actual = {str(p.relative_to(self.destination)) for p in self.destination.rglob("*") if p.is_file()}
        assert set(declared) == actual, f"Unexpected deployment: {actual.symmetric_difference(declared)}"
        assert os.access(self.destination / ".config/tmux/has-battery.sh", os.X_OK)
        self.passed(f"real apply deploys exactly {len(declared)} declared configuration files")

        first = snapshot(self.destination)
        self.chez("apply")
        assert snapshot(self.destination) == first
        assert not self.chez("diff", "--exclude=scripts").stdout.strip()
        self.passed("second apply preserves contents, permissions and modification times")

        sentinel = self.destination / ".config/tmux/unmanaged-fixture.txt"
        sentinel.write_text("preserve unmanaged files\n")
        self.chez("apply")
        assert sentinel.read_text() == "preserve unmanaged files\n"
        self.passed("apply preserves unmanaged runtime files")

        # Finish hooks are intentionally no-ops in isolation. Exercise the real
        # ownership recorder separately, with HOME set to this known fixture.
        record_env = dict(self.env, HOME=str(self.destination))
        self.run(["/bin/bash", self.source / "scripts/bootstrap/record-state.sh"], env=record_env)
        source_prompt = self.source / "home/dot_config/starship.toml"
        source_prompt.write_text(source_prompt.read_text().replace("500", "650"))
        self.chez("apply")
        assert "650" in (self.destination / ".config/starship.toml").read_text()
        self.passed("recorded ownership permits an intentional source update")

        prompt = self.destination / ".config/starship.toml"
        original = prompt.read_bytes()
        prompt.write_bytes(original + b"# local edit\n")
        before = snapshot(self.destination)
        result = self.chez("apply", success=False)
        assert "CONFLICT" in result.stderr + result.stdout
        assert snapshot(self.destination) == before
        prompt.write_bytes(original)
        self.passed("a local edit blocks apply before any destination changes")

        fish = self.destination / ".config/fish/config.fish"
        original_fish = fish.read_bytes()
        fish.unlink()
        fish.symlink_to(self.workspace / "does-not-exist")
        before = snapshot(self.destination)
        self.chez("apply", success=False)
        assert snapshot(self.destination) == before
        fish.unlink()
        fish.write_bytes(original_fish)
        self.passed("a dangling file symlink is refused without following or replacing it")

        nvim = self.destination / ".config/nvim"
        holding = self.workspace / "holding-nvim"
        nvim.rename(holding)
        unrelated = self.workspace / "unrelated-directory"
        unrelated.mkdir()
        (unrelated / "sentinel").write_text("do not change\n")
        nvim.symlink_to(unrelated, target_is_directory=True)
        before = snapshot(self.destination)
        untouched = snapshot(unrelated)
        self.chez("apply", success=False)
        assert snapshot(self.destination) == before and snapshot(unrelated) == untouched
        nvim.unlink()
        holding.rename(nvim)
        self.passed("a directory symlink is refused and its target stays untouched")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chezmoi", required=True, type=Path)
    parser.add_argument("--keep-workspace", action="store_true", help="retain private fixtures and diagnostic logs")
    parser.add_argument("--smoke", action="store_true", help="also use existing Fish/tmux/Neovim binaries and copied plugin caches")
    args = parser.parse_args()
    if not args.chezmoi.is_file() or not os.access(args.chezmoi, os.X_OK):
        parser.error("--chezmoi must point to an executable (no software is installed by this harness)")
    workspace = Path(tempfile.mkdtemp(prefix="dotfiles-chezmoi-test-"))
    live_home = Path.home()
    before = live_metadata(live_home)
    try:
        harness = Harness(workspace, args.chezmoi)
        print(harness.chez("--version").stdout.strip(), flush=True)
        harness.deployment_checks()
        if args.smoke:
            from smoke_apps import smoke
            smoke(harness, ROOT)
        assert live_metadata(live_home) == before, "Live configuration metadata changed"
        harness.passed("live configuration metadata is unchanged")
        print(json.dumps({"passed": len(harness.checks), "checks": harness.checks}, indent=2))
    finally:
        assert live_metadata(live_home) == before, "Live configuration metadata changed"
        if args.keep_workspace:
            print("Private test workspace:", workspace, flush=True)
        else:
            shutil.rmtree(workspace)


if __name__ == "__main__":
    main()
