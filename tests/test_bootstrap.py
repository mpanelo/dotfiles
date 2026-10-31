"""Offline safety tests. All mutable fixtures live in temporary directories.

Never invokes an installer or chezmoi apply. Use Python's standard library only.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts/bootstrap"


def declared_files():
    return [line.split() for line in (ROOT / "manifests/config-files.tsv").read_text().splitlines()
            if line and not line.startswith("#")]


class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home"
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null")
        for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "CARGO_HOME", "RUSTUP_HOME"):
            self.env.pop(key, None)

    def run_script(self, name, *args):
        return subprocess.run(["/bin/bash", str(SCRIPTS / name), *args],
                              env=self.env, text=True, capture_output=True)

    def preflight(self):
        return self.run_script("preflight.sh", "--files-only", "--destination", str(self.home))

    def test_empty_destination_is_read_only_and_repeatable(self):
        for _ in range(2):
            result = self.preflight()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(self.home.iterdir()), [])

    def test_unknown_regular_file_is_not_overwritten(self):
        target = self.home / ".config/fish/config.fish"
        target.parent.mkdir(parents=True)
        target.write_text("# local customization\n")
        result = self.preflight()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CONFLICT", result.stderr)
        self.assertEqual(target.read_text(), "# local customization\n")

    def test_identical_regular_file_can_be_adopted(self):
        target = self.home / ".config/fish/config.fish"
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "home/dot_config/fish/config.fish", target)
        result = self.preflight()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_directory_and_dangling_symlinks_are_refused(self):
        (self.home / ".config").mkdir()
        target = self.home / ".config/fish"
        target.symlink_to(ROOT / "fish", target_is_directory=True)
        result = self.preflight()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(target.is_symlink())
        target.unlink()
        target.symlink_to(self.home / "missing")
        self.assertNotEqual(self.preflight().returncode, 0)
        self.assertTrue(target.is_symlink())

    def test_individual_file_symlink_is_refused(self):
        target = self.home / ".config/tmux/tmux.conf"
        target.parent.mkdir(parents=True)
        target.symlink_to(ROOT / "tmux/tmux.conf")
        self.assertNotEqual(self.preflight().returncode, 0)
        self.assertTrue(target.is_symlink())

    def test_runtime_and_state_symlinks_are_refused(self):
        (self.home / ".local").symlink_to(ROOT, target_is_directory=True)
        self.assertNotEqual(self.preflight().returncode, 0)

    def test_legacy_tmux_config_is_refused(self):
        (self.home / ".tmux.conf").write_text("# preserve me\n")
        self.assertNotEqual(self.preflight().returncode, 0)
        self.assertEqual((self.home / ".tmux.conf").read_text(), "# preserve me\n")

    def test_recorded_ownership_accepts_updates_but_detects_local_edits(self):
        # Simulate a previous successful apply at an older source revision.
        baseline = self.home / ".local/state/dotfiles/managed.sha256"
        baseline.parent.mkdir(parents=True)
        entries = []
        for target, source in declared_files():
            path = self.home / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# old managed version\n")
            entries.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + target)
        baseline.write_text("\n".join(entries) + "\n")
        baseline.chmod(0o600)
        self.assertEqual(self.preflight().returncode, 0)
        target = self.home / ".config/fish/config.fish"
        target.write_text("# new local customization\n")
        self.assertNotEqual(self.preflight().returncode, 0)
        self.assertEqual(target.read_text(), "# new local customization\n")
        self.assertEqual((self.home / ".local/state/dotfiles/managed.sha256").stat().st_mode & 0o777, 0o600)

    def test_record_state_rejects_changes_during_provisioning(self):
        # Stub only rendering; the real state-recording script must still compare
        # every destination and refuse a concurrent edit before recording it.
        bin_dir = Path(self.tmp.name) / "bin"
        bin_dir.mkdir()
        renderer = bin_dir / "chezmoi"
        renderer.write_text("#!/bin/sh\nprintf '# rendered fixture\\n'\n")
        renderer.chmod(0o755)
        self.env["PATH"] = str(bin_dir) + os.pathsep + self.env["PATH"]
        for target, source in declared_files():
            path = self.home / target
            path.parent.mkdir(parents=True, exist_ok=True)
            if not source.endswith(".tmpl"):
                shutil.copyfile(ROOT / "home" / source, path)
            else:
                path.write_text("# rendered fixture\n")
        (self.home / ".config/fish/config.fish").write_text("# edited during install\n")
        result = self.run_script("record-state.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during provisioning", result.stderr)
        self.assertFalse((self.home / ".local/state/dotfiles/managed.sha256").exists())

    def test_backup_preserves_links_and_contents_without_changing_them(self):
        config = self.home / ".config"
        config.mkdir()
        source = Path(self.tmp.name) / "original-fish"
        source.mkdir()
        (source / "config.fish").write_text("# original\n")
        (config / "fish").symlink_to(source, target_is_directory=True)
        result = self.run_script("backup.sh", "--create")
        self.assertEqual(result.returncode, 0, result.stderr)
        backup = Path(result.stdout.strip())
        self.assertEqual(backup.stat().st_mode & 0o777, 0o700)
        self.assertEqual((backup / "files/.config/fish/config.fish").read_text(), "# original\n")
        self.assertEqual(os.readlink(backup / "links/.config/fish"), str(source))
        self.assertEqual(os.readlink(config / "fish"), str(source))
        self.assertEqual((source / "config.fish").read_text(), "# original\n")

    def test_plugin_checkout_is_repeatable_and_refuses_dirty_files(self):
        upstream = Path(self.tmp.name) / "upstream"
        upstream.mkdir()

        def git(*args):
            return subprocess.check_output(["git", "-C", str(upstream), *args], env=self.env,
                                           text=True, stderr=subprocess.DEVNULL).strip()

        git("init", "--quiet")
        (upstream / "plugin.conf").write_text("first version\n")
        git("add", "plugin.conf")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "fixture")
        pin = git("rev-parse", "HEAD")
        target = self.home / ".local/share/dotfiles/plugin-fixture"

        def sync():
            return subprocess.run(["/bin/bash", "-c", 'source "$1"; sync_checkout "$2" "$3" "$4"',
                                   "fixture", str(SCRIPTS / "lib.sh"), str(target), str(upstream), pin],
                                  env=self.env, text=True, capture_output=True)

        for _ in range(2):
            result = sync()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((target / "plugin.conf").read_text(), "first version\n")
        (target / "plugin.conf").write_text("local customization\n")
        result = sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local changes", result.stderr)
        self.assertEqual((target / "plugin.conf").read_text(), "local customization\n")


class SourceTests(unittest.TestCase):
    def test_declared_files_exactly_cover_source_state(self):
        sources = {s for _, s in declared_files()}
        actual = {str(p.relative_to(ROOT / "home")) for p in (ROOT / "home").rglob("*")
                  if p.is_file() and not p.relative_to(ROOT / "home").parts[0].startswith((".chezmoi", "run_"))}
        self.assertEqual(sources, actual)
        self.assertEqual(len(sources), len(declared_files()))

    def test_nvim_repositories_exactly_cover_lockfile(self):
        lock = json.loads((ROOT / "home/dot_config/nvim/lazy-lock.json").read_text())
        repos = {line.split()[0] for line in (ROOT / "manifests/nvim-plugins.tsv").read_text().splitlines()
                 if line and not line.startswith("#")}
        self.assertEqual(set(lock), repos)
        self.assertEqual(lock, json.loads((ROOT / "nvim/lazy-lock.json").read_text()))

    def test_only_agreed_nvim_behavior_changes(self):
        for path in (ROOT / "nvim").rglob("*"):
            if not path.is_file() or path.name == "README.md":
                continue
            rel = path.relative_to(ROOT / "nvim")
            new = ROOT / "home/dot_config/nvim" / rel
            if str(rel) in ("lua/config/lazy.lua", "lua/plugins/formatting.lua", "lua/plugins/nvim-treesitter.lua"):
                continue
            self.assertEqual(path.read_bytes(), new.read_bytes(), str(rel))
        old = (ROOT / "nvim/lua/plugins/formatting.lua").read_text()
        new = (ROOT / "home/dot_config/nvim/lua/plugins/formatting.lua").read_text()
        self.assertEqual(old.replace('\t\t\tbash = { "shfmt" },\n', ''), new)

    def test_tmux_only_removes_sessionx(self):
        old = (ROOT / "tmux/tmux.conf").read_text()
        new = (ROOT / "home/dot_config/tmux/tmux.conf").read_text()
        self.assertEqual(old.replace("set -g @plugin 'omerxx/tmux-sessionx'\n", ""), new)
        self.assertNotIn("sessionx", (ROOT / "manifests/tmux-plugins.tsv").read_text())

    def test_no_frontend_or_unagreed_packages(self):
        brewfile = (ROOT / "Brewfile").read_text()
        packages = re.findall(r'^brew "([^"]+)"', brewfile, re.M)
        for forbidden in ("node", "npm", "basedpyright", "typescript", "shfmt", "cloc", "wget"):
            self.assertNotIn(forbidden, packages)
        self.assertIn("fnm", packages)
        self.assertIn("ssh-copy-id", packages)
        for path in (ROOT / "scripts/bootstrap").glob("*.sh"):
            self.assertNotRegex(path.read_text(), r'\bfnm\s+install\b|\bnpm\s+(install|i)\b')

    def test_python_constraints_match_versions(self):
        versions = json.loads((ROOT / "manifests/versions.json").read_text())
        pins = dict(line.split("==") for line in (ROOT / "manifests/python-tools.constraints.txt").read_text().splitlines()
                    if line and not line.startswith("#"))
        self.assertEqual(pins, {k: versions[k] for k in pins})

    def test_empty_config_files_explicitly_request_creation(self):
        for target, source in declared_files():
            if (ROOT / "home" / source).stat().st_size == 0:
                self.assertTrue(Path(source).name.startswith("empty_"), target + " would be skipped by chezmoi")

    def test_all_new_shell_scripts_parse(self):
        for path in [ROOT / "bootstrap.sh", ROOT / "install.sh", ROOT / "tests/run-isolated.sh", *SCRIPTS.glob("*.sh")]:
            result = subprocess.run(["/bin/bash", "-n", str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        fish = shutil.which("fish")
        if fish:
            for path in (ROOT / "home").rglob("*.fish"):
                result = subprocess.run([fish, "--no-config", "--no-execute", str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
