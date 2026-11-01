"""Offline safety tests. All mutable fixtures live in temporary directories.

Never invokes an installer or chezmoi apply. Use Python's standard library only.
"""
import hashlib
import gzip
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts/bootstrap"


def declared_files():
    return [line.split() for line in (ROOT / "manifests/config-files.tsv").read_text().splitlines()
            if line and not line.startswith("#")]


def populate_fish_files(home):
    paths = []
    for relative, _source in declared_files():
        if relative.startswith(".config/fish/") and relative.endswith(".fish"):
            path = home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# managed fixture\n")
            paths.append(path)
    return paths


class FontTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-font-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / "alacritty.toml"

    def verify(self):
        return subprocess.run(
            [sys.executable, "-I", str(SCRIPTS / "verify-font.py"), str(self.config)],
            env=dict(os.environ, HOME=str(self.home)), text=True, capture_output=True,
        )

    @unittest.skipUnless(sys.platform == "darwin", "Requires macOS CoreText")
    def test_available_native_font_passes_without_config_changes(self):
        original = '[font.normal]\nfamily = "Menlo"\n'
        self.config.write_text(original)
        for _ in range(2):
            result = self.verify()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Font available to macOS: Menlo", result.stdout)
            self.assertEqual(self.config.read_text(), original)
            self.assertEqual(list(self.home.iterdir()), [self.config])

    @unittest.skipUnless(sys.platform == "darwin", "Requires macOS CoreText")
    def test_font_file_presence_does_not_pass_unavailable_family(self):
        self.config.write_text('[font.normal]\nfamily = "Dotfiles Missing Font Fixture"\n')
        font = self.home / "Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
        font.parent.mkdir(parents=True)
        font.write_bytes(b"Unregistered font fixture; never installed")
        result = self.verify()
        self.assertEqual(result.returncode, 1)
        self.assertIn("not visible to macOS CoreText", result.stderr)
        self.assertIn("log out or restart", result.stderr)
        self.assertNotIn("Font available", result.stdout)
        self.assertEqual(font.read_bytes(), b"Unregistered font fixture; never installed")

    def test_undeclared_family_is_reported_before_font_discovery(self):
        self.config.write_text("[font]\nsize = 18.0\n")
        result = self.verify()
        self.assertEqual(result.returncode, 1)
        self.assertIn("must declare font.normal.family", result.stderr)


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

    def preflight(self, *args):
        return self.run_script("preflight.sh", "--files-only", "--destination", str(self.home), *args)

    def test_empty_destination_is_read_only_and_repeatable(self):
        for _ in range(2):
            result = self.preflight()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(self.home.iterdir()), [])
            count = len(declared_files())
            self.assertIn(f"{count} checked; {count} absent, 0 matching", result.stdout)
            self.assertIn("platform, app/font and prerequisite checks are skipped", result.stdout)
            self.assertIn("not a completed provisioning check", result.stdout)
            self.assertIn("Not checked: network access", result.stdout)

    def test_quiet_preflight_is_silent_and_read_only_on_success(self):
        result = self.preflight("--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")
        self.assertEqual(list(self.home.iterdir()), [])

    def test_bootstrap_help_and_removed_plan_do_not_provision(self):
        for arg, expected_code in (("--help", 0), ("--plan", 1)):
            result = subprocess.run(["/bin/bash", str(ROOT / "bootstrap.sh"), arg],
                                    env=self.env, text=True, capture_output=True)
            self.assertEqual(result.returncode, expected_code, result.stderr)
            self.assertEqual(list(self.home.iterdir()), [])
            if arg == "--help":
                self.assertNotIn("--plan", result.stdout)
                self.assertIn("without installing or applying", result.stdout)
                self.assertIn("does not mean the tools are installed", result.stdout)
            else:
                self.assertIn("Unknown argument", result.stderr)

    def test_unknown_regular_file_is_not_overwritten(self):
        target = self.home / ".config/fish/config.fish"
        target.parent.mkdir(parents=True)
        target.write_text("# local customization\n")
        for args in ((), ("--quiet",)):
            with self.subTest(args=args):
                result = self.preflight(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("CONFLICT: .config/fish/config.fish differs", result.stderr)
                self.assertIn("Installation blocked by 1 conflict(s)", result.stderr)
                self.assertNotIn("check passed", result.stdout)
                self.assertNotIn("# local customization", result.stdout + result.stderr)
                self.assertEqual(target.read_text(), "# local customization\n")

    def test_identical_regular_file_can_be_adopted(self):
        target = self.home / ".config/fish/config.fish"
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "home/dot_config/fish/config.fish", target)
        result = self.preflight()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1 matching", result.stdout)

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

    def test_tool_directory_links_are_refused(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        for relative in ("go/bin", ".cargo/bin", ".local/share/uv/tools/basedpyright", ".local/share/uv/tools/ruff"):
            with self.subTest(relative=relative):
                path = self.home / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.symlink_to(outside, target_is_directory=True)
                result = self.preflight()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f"Unsafe runtime directory: {relative}", result.stderr)
                self.assertTrue(path.is_symlink())
                self.assertEqual(list(outside.iterdir()), [])
                path.unlink()

    def test_fish_checks_only_owned_files(self):
        declared = populate_fish_files(self.home)
        owned = self.home / ".config/fish/functions/owned.fish"
        owned.write_text("# owned plugin fixture\n")
        unknown = owned.with_name("unrelated.fish")
        unknown.write_text("synthetic private fixture; never read\n")
        inventory = self.home / ".local/state/dotfiles/fish-plugin-files.sha256"
        inventory.parent.mkdir(parents=True)
        inventory.write_text("a" * 64 + "  .config/fish/functions/owned.fish\n")
        checker = Path(self.tmp.name) / "fish"
        log = Path(self.tmp.name) / "checked.txt"
        checker.write_text('#!/bin/sh\nprintf "%s\\n" "$3" >> "$CHECK_LOG"\n')
        checker.chmod(0o755)
        self.env["CHECK_LOG"] = str(log)
        code = 'source "$1"; check_fish_syntax "$2"'
        result = subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS / "lib.sh"), str(checker)], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(log.read_text().splitlines()), set(map(str, [*declared, owned])))
        self.assertEqual(unknown.read_text(), "synthetic private fixture; never read\n")

    def test_legacy_tmux_config_is_refused(self):
        (self.home / ".tmux.conf").write_text("# preserve me\n")
        self.assertNotEqual(self.preflight().returncode, 0)
        self.assertEqual((self.home / ".tmux.conf").read_text(), "# preserve me\n")

    def test_truncated_editor_lock_is_backed_up_and_repaired_idempotently(self):
        target = self.home / ".config/nvim/lazy-lock.json"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"{\n")
        result = self.run_script("repair-editor-lock.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_bytes(), (ROOT / "home/dot_config/nvim/lazy-lock.json").read_bytes())
        backups = list((self.home / ".local/state/dotfiles/backups").glob("editor-lock.*/lazy-lock.json"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), b"{\n")
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(backups[0].parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.run_script("repair-editor-lock.sh").returncode, 0)
        self.assertEqual(len(list(backups[0].parent.parent.iterdir())), 1)

    def test_lock_repair_preserves_divergent_files_and_symlinks(self):
        target = self.home / ".config/nvim/lazy-lock.json"
        target.parent.mkdir(parents=True)
        for content in (b'{"custom": {"commit": "keep"}}\n', b"{\n  \"partially edited\": "):
            target.write_bytes(content)
            result = self.run_script("repair-editor-lock.sh")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), content)
        target.unlink()
        original = self.home / "original-lock"
        original.write_bytes(b"{\n")
        target.symlink_to(original)
        self.assertNotEqual(self.run_script("repair-editor-lock.sh").returncode, 0)
        self.assertTrue(target.is_symlink())
        self.assertEqual(original.read_bytes(), b"{\n")

    def test_empty_editor_lock_can_be_repaired(self):
        target = self.home / ".config/nvim/lazy-lock.json"
        target.parent.mkdir(parents=True)
        target.touch()
        self.assertEqual(self.run_script("repair-editor-lock.sh").returncode, 0)
        self.assertEqual(target.read_bytes(), (ROOT / "home/dot_config/nvim/lazy-lock.json").read_bytes())

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
        result = self.preflight()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"{len(declared_files())} unchanged since last apply", result.stdout)
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
        legacy = source
        source = legacy / "fish"
        source.mkdir(parents=True)
        (source / "config.fish").write_text("# original\n")
        (config / "fish").symlink_to(source, target_is_directory=True)
        result = self.run_script("backup.sh", "--create", "--legacy-root", str(legacy))
        self.assertEqual(result.returncode, 0, result.stderr)
        backup = Path(result.stdout.strip())
        self.assertEqual(backup.stat().st_mode & 0o777, 0o700)
        self.assertEqual((backup / "files/.config/fish/config.fish").read_text(), "# original\n")
        self.assertEqual(os.readlink(backup / "links/.config/fish"), str(source))
        self.assertEqual(os.readlink(config / "fish"), str(source))
        self.assertEqual((source / "config.fish").read_text(), "# original\n")

    def test_backup_refuses_unrecognized_links(self):
        source = Path(self.tmp.name) / "unrelated"
        source.mkdir()
        content = "synthetic private fixture; never copy\n"
        (source / "config.fish").write_text(content)
        config = self.home / ".config"
        config.mkdir()
        (config / "fish").symlink_to(source, target_is_directory=True)
        result = self.run_script("backup.sh", "--create")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unrecognized link", result.stderr)
        self.assertNotIn(content, result.stdout + result.stderr)
        self.assertEqual((source / "config.fish").read_text(), content)
        self.assertFalse(list((self.home / ".local/state/dotfiles/backups").glob("*/files/.config/fish/config.fish")))

    def test_backup_preserves_file_link_metadata(self):
        legacy = Path(self.tmp.name) / "legacy"
        original = legacy / "tmux/tmux.conf"
        original.parent.mkdir(parents=True)
        original.write_text("# legacy tmux\n")
        target = self.home / ".config/tmux/tmux.conf"
        target.parent.mkdir(parents=True)
        target.symlink_to(original)
        result = self.run_script("backup.sh", "--create", "--legacy-root", str(legacy))
        self.assertEqual(result.returncode, 0, result.stderr)
        backup = Path(result.stdout.strip())
        self.assertEqual(os.readlink(backup / "links/.config/tmux/tmux.conf"), str(original))
        self.assertEqual((backup / "files/.config/tmux/tmux.conf").read_text(), "# legacy tmux\n")
        self.assertTrue(target.is_symlink())

    @unittest.skipUnless(os.uname().sysname == "Darwin", "macOS launcher")
    def test_launcher_refuses_linked_git_metadata(self):
        checkout = self.home / ".local/share/chezmoi"
        checkout.mkdir(parents=True)
        unrelated = Path(self.tmp.name) / "unrelated-git"
        unrelated.mkdir()
        (checkout / ".git").symlink_to(unrelated, target_is_directory=True)
        result = subprocess.run(["/bin/bash", str(ROOT / "install.sh"), "a" * 40], env=self.env,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlinked Git directory", result.stderr)
        self.assertEqual(list(unrelated.iterdir()), [])

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

        def sync(branch=""):
            return subprocess.run(["/bin/bash", "-c", 'source "$1"; sync_checkout "$2" "$3" "$4" "$5"',
                                   "fixture", str(SCRIPTS / "lib.sh"), str(target), str(upstream), pin, branch],
                                  env=self.env, text=True, capture_output=True)

        for _ in range(2):
            result = sync()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((target / "plugin.conf").read_text(), "first version\n")
        # A retry at an unchanged pin must also repair missing branch metadata.
        result = sync("main")
        self.assertEqual(result.returncode, 0, result.stderr)
        ref = subprocess.check_output(["git", "-C", str(target), "symbolic-ref", "refs/remotes/origin/HEAD"], env=self.env, text=True).strip()
        self.assertEqual(ref, "refs/remotes/origin/main")
        self.assertEqual(subprocess.check_output(["git", "-C", str(target), "rev-parse", ref], env=self.env, text=True).strip(), pin)
        (upstream / "plugin.conf").write_text("later upstream version\n")
        git("add", "plugin.conf")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "later fixture")
        later = git("rev-parse", "HEAD")
        subprocess.run(["git", "-C", str(target), "fetch", "--quiet", "origin", later], env=self.env, check=True)
        subprocess.run(["git", "-C", str(target), "update-ref", ref, later], env=self.env, check=True)
        self.assertEqual(sync("main").returncode, 0)
        self.assertEqual(subprocess.check_output(["git", "-C", str(target), "rev-parse", ref], env=self.env, text=True).strip(), later)
        self.assertEqual(subprocess.check_output(["git", "-C", str(target), "rev-parse", "HEAD"], env=self.env, text=True).strip(), pin)
        (target / "plugin.conf").write_text("local customization\n")
        result = sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local changes", result.stderr)
        self.assertEqual((target / "plugin.conf").read_text(), "local customization\n")


class InstallerTests(unittest.TestCase):
    setUp = SafetyTests.setUp

    def test_verified_download_gates_execution(self):
        root = Path(self.tmp.name)
        marker = root / "executed"
        payload = root / "installer-fixture"
        payload.write_text('#!/bin/sh\nprintf "executed\\n" > "$EXECUTION_MARKER"\n')
        manifest = root / "manifests/installers.tsv"
        manifest.parent.mkdir()
        bin_dir = root / "bin"
        bin_dir.mkdir()
        curl = bin_dir / "curl"
        curl.write_text('#!/bin/sh\nset -eu\n[ "$1" = -q ]\nwhile [ "$1" != -o ]; do shift; done\ncp "$DOWNLOAD_PAYLOAD" "$2"\n')
        curl.chmod(0o755)
        self.env.update(PATH=str(bin_dir) + os.pathsep + self.env["PATH"],
                        DOWNLOAD_PAYLOAD=str(payload), EXECUTION_MARKER=str(marker))
        for valid in (False, True):
            with self.subTest(valid=valid):
                checksum = hashlib.sha256(payload.read_bytes()).hexdigest() if valid else "0" * 64
                manifest.write_text(f"fixture https://example.invalid/pinned/installer {checksum}\n")
                code = 'source "$1"; REPO_ROOT=$2; download_installer fixture "$2/downloaded"; /bin/sh "$2/downloaded"'
                result = subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS / "lib.sh"), str(root)], env=self.env,
                                        text=True, capture_output=True)
                if valid:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(marker.exists())
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("checksum mismatch", result.stderr)
                    self.assertFalse(marker.exists())


class BlinkBuildTests(unittest.TestCase):
    setUp = SafetyTests.setUp

    def test_isolated_startup_requires_pinned_plugins(self):
        nvim = shutil.which("nvim")
        if not nvim:
            self.skipTest("requires Neovim; no installation is attempted")
        root = Path(self.tmp.name) / "source"
        lockfile = root / "home/dot_config/nvim/lazy-lock.json"
        lockfile.parent.mkdir(parents=True)
        marker = self.home / "native-build-started"
        helper = root / "scripts/bootstrap/build-blink.lua"
        helper.parent.mkdir(parents=True)
        helper.write_text('return function() local f = assert(io.open(vim.env.DOTFILES_BUILD_MARKER, "w")); f:write("built"); f:close() end\n')
        lock = {}
        for name in ("blink.lib", "blink.cmp"):
            plugin = self.home / ".local/share/nvim/lazy" / name
            plugin.mkdir(parents=True)
            (plugin / "fixture.txt").write_text("plugin fixture\n")
            if name == "blink.cmp":
                fuzzy = plugin / "lua/blink/cmp/fuzzy.lua"
                fuzzy.parent.mkdir(parents=True)
                fuzzy.write_text('return { set_implementation = function(name) assert(name == "rust"); assert(io.open(vim.env.DOTFILES_BUILD_MARKER)):close() end }\n')
            commands = (("init", "--quiet"), ("add", "."),
                        ("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "fixture"))
            for command in commands:
                subprocess.run(["git", "-C", str(plugin), *command], env=self.env, check=True)
            pin = subprocess.check_output(["git", "-C", str(plugin), "rev-parse", "HEAD"], env=self.env, text=True).strip()
            lock[name] = {"commit": pin}
        # The real configuration must not run before the native repair process.
        init = self.home / ".config/nvim/init.lua"
        init.parent.mkdir(parents=True)
        init.write_text('error("managed startup ran before native repair")\n')
        env = dict(self.env, XDG_CONFIG_HOME=str(self.home / ".config"),
                   XDG_DATA_HOME=str(self.home / ".local/share"),
                   XDG_STATE_HOME=str(self.home / ".local/state"),
                   XDG_CACHE_HOME=str(self.home / ".cache"), DOTFILES_REPO_ROOT=str(root),
                   DOTFILES_BUILD_MARKER=str(marker), DOTFILES_BLINK_ENTRY=str(SCRIPTS / "install-blink.lua"))
        for wrong_pin in (False, True):
            with self.subTest(wrong_pin=wrong_pin):
                if marker.exists():
                    marker.unlink()
                if wrong_pin:
                    lock["blink.cmp"]["commit"] = "0" * 40
                lockfile.write_text(json.dumps(lock))
                result = subprocess.run([nvim, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-c", 'lua dofile(vim.env.DOTFILES_BLINK_ENTRY)'], env=env, text=True, capture_output=True, timeout=30)
                if wrong_pin:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Plugin differs from its pin", result.stderr)
                    self.assertFalse(marker.exists())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(marker.exists())

    def test_rebuild_and_failure_handling(self):
        nvim = shutil.which("nvim")
        if not nvim:
            self.skipTest("requires Neovim; no installation is attempted")
        env = dict(self.env, XDG_CONFIG_HOME=str(self.home / ".config"),
                   XDG_DATA_HOME=str(self.home / ".local/share"),
                   XDG_STATE_HOME=str(self.home / ".local/state"),
                   XDG_CACHE_HOME=str(self.home / ".cache"),
                   DOTFILES_BLINK_BUILDER=str(SCRIPTS / "build-blink.lua"),
                   DOTFILES_BLINK_TEST=str(ROOT / "tests/blink-build-regression.lua"))
        result = subprocess.run([nvim, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-c", 'lua dofile(vim.env.DOTFILES_BLINK_TEST)'], env=env, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("DOTFILES_BLINK_BUILD_OK: 5 scenarios", result.stdout + result.stderr)


class EditorBootstrapTests(unittest.TestCase):
    setUp = SafetyTests.setUp

    def prepare_editor(self, wrong_pin=False, parser_failure=""):
        executable = shutil.which("nvim")
        cached = Path.home() / ".local/share/nvim/lazy/lazy.nvim"
        if not executable or not (cached / ".git").is_dir():
            self.skipTest("requires an existing Neovim and pinned lazy.nvim cache; no download is attempted")
        expected = json.loads((ROOT / "home/dot_config/nvim/lazy-lock.json").read_text())["lazy.nvim"]["commit"]
        actual = subprocess.check_output(["git", "-C", str(cached), "rev-parse", "HEAD"], text=True).strip()
        if actual != expected:
            self.skipTest("cached lazy.nvim is not the pinned revision")
        subprocess.run(["git", "-C", str(cached), "diff", "--quiet", "HEAD", "--", "lua"], check=True)
        self.fixture = Path(self.tmp.name) / ("editor-" + (parser_failure or "normal"))
        self.fixture.mkdir()
        shutil.copytree(cached / "lua", self.fixture / "lazy.nvim/lua", symlinks=True)
        upstream = self.fixture / "upstream"
        upstream.mkdir()
        subprocess.run(["git", "-C", str(upstream), "init", "--quiet"], env=self.env, check=True)
        (upstream / "fixture.txt").write_text("pinned plugin fixture\n")
        subprocess.run(["git", "-C", str(upstream), "add", "fixture.txt"], env=self.env, check=True)
        subprocess.run(["git", "-C", str(upstream), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "fixture"], env=self.env, check=True)
        pin = subprocess.check_output(["git", "-C", str(upstream), "rev-parse", "HEAD"], env=self.env, text=True).strip()
        # Use the original three-argument seeding shape to reproduce the exact
        # branchless detached checkout from the failed clean-Mac bootstrap.
        code = 'source "$1"; sync_checkout "$2" "$3" "$4"'
        # sync_checkout only permits destinations under its disposable HOME.
        self.plugin = self.home / ("plugin-" + (parser_failure or "normal"))
        subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS / "lib.sh"), str(self.plugin), str(upstream), pin], env=self.env, check=True)
        (self.fixture / "plugin").symlink_to(self.plugin, target_is_directory=True)
        lock = {"fixture": {"branch": "main", "commit": "0" * 40 if wrong_pin else pin}}
        self.lockfile = self.fixture / "lazy-lock.json"
        self.lockfile.write_text(json.dumps(lock) + "\n")
        self.lock_bytes = self.lockfile.read_bytes()
        verify = self.fixture / "scripts/bootstrap/verify-editor.lua"
        verify.parent.mkdir(parents=True)
        verify.write_text('local f = assert(io.open(vim.env.DOTFILES_EDITOR_FIXTURE .. "/lazy-lock.json", "rb")); local bytes = f:read("*a"); f:close(); assert(bytes == vim.g.dotfiles_expected_lock, "lockfile was modified"); print("DOTFILES_EDITOR_LOCK_OK")\n')
        env = dict(self.env, XDG_CONFIG_HOME=str(self.home / ".config"),
                   XDG_DATA_HOME=str(self.home / ".local/share"),
                   XDG_STATE_HOME=str(self.home / ".local/state"),
                   XDG_CACHE_HOME=str(self.home / ".cache"), GIT_ALLOW_PROTOCOL="file",
                   DOTFILES_EDITOR_FIXTURE=str(self.fixture), DOTFILES_REPO_ROOT=str(self.fixture),
                   DOTFILES_EDITOR_INSTALLER=str(SCRIPTS / "install-editor.lua"),
                   DOTFILES_PARSER_FAILURE=parser_failure,
                   DOTFILES_EDITOR_TEST=str(ROOT / "tests/editor-lock-regression.lua"))
        return subprocess.run([executable, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-c", 'lua dofile(vim.env.DOTFILES_EDITOR_TEST)'], env=env, text=True, capture_output=True, timeout=30)

    def test_seeded_plugins_build_without_lazy_restore_or_lockfile_writes(self):
        result = self.prepare_editor()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("DOTFILES_EDITOR_LOCK_OK", result.stdout + result.stderr)
        self.assertEqual(self.lockfile.read_bytes(), self.lock_bytes)

    def test_wrong_plugin_revision_stops_before_builds_and_preserves_lock(self):
        result = self.prepare_editor(wrong_pin=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Plugin differs from its pin", result.stderr)
        self.assertNotIn("DOTFILES_EDITOR_LOCK_OK", result.stdout + result.stderr)
        self.assertEqual(self.lockfile.read_bytes(), self.lock_bytes)

    def test_parser_failures_stop_verification(self):
        for stage, message in (("install", "installation"), ("update", "update")):
            with self.subTest(stage=stage):
                result = self.prepare_editor(parser_failure=stage)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f"Tree-sitter parser {message} failed", result.stderr)
                self.assertNotIn("DOTFILES_EDITOR_LOCK_OK", result.stdout + result.stderr)
                self.assertEqual(self.lockfile.read_bytes(), self.lock_bytes)


class TreeSitterTests(unittest.TestCase):
    setUp = SafetyTests.setUp

    def prepare_release(self, arch="arm64", reported_version="0.26.8"):
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.archive = self.root / "release.gz"
        self.archive.write_bytes(gzip.compress(f'#!/bin/sh\nprintf "tree-sitter {reported_version}\\n"\n'.encode()))
        (self.root / "manifests").mkdir()
        checksum = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.root / "manifests/versions.json").write_text(json.dumps({
            "tree-sitter-cli": "0.26.8", "tree-sitter-macos-arm64-sha256": checksum,
            "tree-sitter-macos-x64-sha256": checksum}))
        self.log = self.root / "downloads.log"
        commands = {
            "curl": 'printf "%s\\n" "$*" >> "$DOWNLOAD_LOG"\nwhile [ "$1" != "-o" ]; do shift; done\ncp "$FIXTURE_ARCHIVE" "$2"\n',
            "lipo": 'exit 0\n',
            "uname": f'printf "{arch}\\n"\n',
        }
        for name, body in commands.items():
            path = self.bin / name
            path.write_text("#!/bin/sh\nset -eu\n" + body)
            path.chmod(0o755)
        self.env.update(PATH=str(self.bin) + os.pathsep + self.env["PATH"],
                        FIXTURE_ARCHIVE=str(self.archive), DOWNLOAD_LOG=str(self.log),
                        TMPDIR=str(self.root))
        self.target = self.home / ".local/bin/tree-sitter"

    def install(self):
        code = 'source "$1/lib.sh"; source "$1/tree-sitter.sh"; REPO_ROOT=$2; install_tree_sitter; tree_sitter_is_current'
        return subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS), str(self.root)],
                              env=self.env, text=True, capture_output=True)

    def test_install_and_retry_reuse_verified_binary(self):
        self.prepare_release()
        for _ in range(2):
            result = self.install()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.log.read_text().splitlines()), 1)
        self.assertIn("tree-sitter-macos-arm64.gz", self.log.read_text())
        self.assertEqual(subprocess.check_output([str(self.target), "--version"], text=True), "tree-sitter 0.26.8\n")
        record = self.home / ".local/state/dotfiles/tree-sitter.release"
        self.assertEqual(record.stat().st_mode & 0o777, 0o600)
        self.assertFalse(list(self.root.glob("dotfiles-tree-sitter.*")))

    def test_intel_selects_the_x64_release(self):
        self.prepare_release(arch="x86_64")
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("tree-sitter-macos-x64.gz", self.log.read_text())

    def test_corrupt_archive_is_rejected_before_installation(self):
        self.prepare_release()
        self.archive.write_bytes(b"corrupt download")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertFalse(self.target.exists())

    def test_unknown_and_locally_modified_binaries_are_preserved(self):
        self.prepare_release()
        self.target.parent.mkdir(parents=True)
        self.target.write_text("unknown executable\n")
        self.target.chmod(0o755)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.target.read_text(), "unknown executable\n")
        self.target.unlink()
        self.assertEqual(self.install().returncode, 0)
        self.target.write_text("local modification\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.target.read_text(), "local modification\n")

    def test_wrong_release_version_is_not_installed(self):
        self.prepare_release(reported_version="0.26.80")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("version mismatch", result.stderr)
        self.assertFalse(self.target.exists())


class WorkflowTests(unittest.TestCase):
    setUp = SafetyTests.setUp

    def prepare_commands(self):
        self.root = Path(self.tmp.name)
        self.bin = self.root / "brew/bin"
        self.bin.mkdir(parents=True)
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.account_shell = self.root / "account-shell"
        self.account_shell.write_text("/bin/zsh\n")
        self.calls = self.root / "calls.log"
        self.packages = self.root / "packages.txt"
        self.packages.write_text("fish 4.9.3\n")
        populate_fish_files(self.home)
        self.env.update(ACCOUNT_SHELL=str(self.account_shell), CALL_LOG=str(self.calls),
                        PACKAGE_FILE=str(self.packages), PRIVATE_SENTINEL="must-not-be-logged")
        commands = {
            "dscl": 'printf "UserShell: %s\\n" "$(cat "$ACCOUNT_SHELL")"\n',
            "fish": 'exit 0\n',
            "sudo": 'printf "sudo\\n" >> "$CALL_LOG"\nexec "$@"\n',
            "chsh": 'printf "chsh\\n" >> "$CALL_LOG"\nprintf "%s\\n" "$2" > "$ACCOUNT_SHELL"\n',
            "brew": '''case "$1" in
list) if [ "$2" = --formula ]; then cat "$PACKAGE_FILE"; fi ;;
tap) printf 'raine/workmux\\n' ;;
info) printf '==> Caveats\\nOptional shell integration\\n' ;;
bundle) printf 'tmux 3.8\\n' >> "$PACKAGE_FILE"; printf 'partial install output\\n'; printf 'fixture failure\\n' >&2; exit 17 ;;
*) exit 99 ;;
esac
''',
        }
        for name, body in commands.items():
            command = self.bin / name
            command.write_text("#!/bin/sh\nset -eu\n" + body)
            command.chmod(0o755)

    def shell(self, code, *args):
        prefix = 'source "$1/lib.sh"; source "$1/session.sh"; source "$1/login-shell.sh"; BREW_PREFIX=$2; '
        return subprocess.run(["/bin/bash", "-c", prefix + code, "fixture", str(SCRIPTS),
                               str(self.bin.parent), *map(str, args)],
                              env=self.env, text=True, capture_output=True)

    def test_failed_install_keeps_status_output_caveats_and_original_inventory(self):
        self.prepare_commands()
        result = self.shell('begin_bootstrap_run; status=0; run_logged brew-bundle "$BREW_PREFIX/bin/brew" bundle || status=$?; save_brew_caveats; exit "$status"')
        self.assertEqual(result.returncode, 17, result.stderr)
        runs = list((self.home / ".local/state/dotfiles/runs").iterdir())
        self.assertEqual(len(runs), 1)
        run = runs[0]
        self.assertEqual(run.stat().st_mode & 0o777, 0o700)
        self.assertEqual((run / "formulae-before.txt").read_text(), "fish 4.9.3\n")
        self.assertIn("tmux 3.8", (run / "formulae-after.txt").read_text())
        self.assertIn("partial install output", (run / "brew-bundle.log").read_text())
        self.assertIn("fixture failure", (run / "brew-bundle.log").read_text())
        self.assertIn("Optional shell integration", (run / "brew-info.txt").read_text())
        self.assertEqual((run / "login-shell-before.txt").read_text(), "UserShell: /bin/zsh\n")
        for path in run.iterdir():
            self.assertNotIn(self.env["PRIVATE_SENTINEL"], path.read_text())

    def test_login_shell_registration_and_change_are_idempotent(self):
        self.prepare_commands()
        registry = self.root / "shells"
        registry.write_text("/bin/zsh\n/bin/bash\n")
        result = self.shell('begin_bootstrap_run; set_fish_login_shell "$BREW_PREFIX/bin/fish" "$3"; set_fish_login_shell "$BREW_PREFIX/bin/fish" "$3"; verify_fish_login_shell', registry)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), ["sudo", "chsh"])
        self.assertEqual(registry.read_text().splitlines().count(str(self.bin / "fish")), 1)
        self.assertTrue(registry.read_text().startswith("/bin/zsh\n/bin/bash\n"))
        self.assertEqual(self.account_shell.read_text().strip(), str(self.bin / "fish"))

    def test_failed_chsh_does_not_claim_the_shell_changed(self):
        self.prepare_commands()
        (self.bin / "chsh").write_text("#!/bin/sh\nexit 23\n")
        registry = self.root / "shells"
        registry.write_text("/bin/zsh\n")
        result = self.shell('set_fish_login_shell "$BREW_PREFIX/bin/fish" "$3"', registry)
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(self.account_shell.read_text(), "/bin/zsh\n")
        self.assertNotIn("Fish is the account login shell", result.stdout)


@unittest.skipUnless(Path("/usr/libexec/PlistBuddy").exists(), "macOS app bundle tests")
class AlacrittyTests(unittest.TestCase):
    """Exercise the real installer with offline assets and fake disk mounting."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-alacritty-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.source = self.root / "Alacritty.app"
        (self.source / "Contents/MacOS").mkdir(parents=True)
        self.executable = self.source / "Contents/MacOS/alacritty"
        self.executable.write_text("fixture executable; never executed\n")
        self.executable.chmod(0o755)
        (self.source / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "org.alacritty", "CFBundleShortVersionString": "0.17.0"}))
        self.dmg = self.root / "fixture.dmg"
        self.dmg.write_bytes(b"offline DMG fixture")
        (self.root / "manifests").mkdir()
        (self.root / "manifests/versions.json").write_text(json.dumps({
            "alacritty": "0.17.0",
            "alacritty-dmg-sha256": hashlib.sha256(self.dmg.read_bytes()).hexdigest()}))
        commands = {
            "curl": 'printf "download\\n" >> "$CALL_LOG"\nwhile [ "$1" != "-o" ]; do shift; done\ncp "$FIXTURE_DMG" "$2"\n',
            "hdiutil": 'printf "%s\\n" "$1" >> "$CALL_LOG"\nif [ "$1" = attach ]; then\nwhile [ "$1" != "-mountpoint" ]; do shift; done\ncp -R "$FIXTURE_APP" "$2/Alacritty.app"\nfi\n',
            "lipo": 'exit 0\n',
            "infocmp": 'exit 0\n',  # Existing definitions must be preserved.
            "tic": 'printf "unexpected terminfo write\\n" >&2\nexit 1\n',
        }
        for command, body in commands.items():
            path = self.bin / command
            path.write_text("#!/bin/sh\nset -eu\n" + body)
            path.chmod(0o755)
        self.log = self.root / "calls.log"
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        FIXTURE_APP=str(self.source), FIXTURE_DMG=str(self.dmg),
                        CALL_LOG=str(self.log), TMPDIR=str(self.root))
        self.app = self.home / "Applications/Alacritty.app"

    def install(self):
        # The fake Brew prefix prevents accidental reuse of a real global app.
        code = 'source "$1/lib.sh"; source "$1/alacritty.sh"; REPO_ROOT=$2; BREW_PREFIX=$2/brew; install_alacritty'
        return subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS), str(self.root)],
                              env=self.env, text=True, capture_output=True)

    def test_fingerprint_propagates_read_failures(self):
        for command in ("find", "stat"):
            with self.subTest(command=command):
                failed = self.bin / command
                failed.write_text("#!/bin/sh\nexit 37\n")
                failed.chmod(0o755)
                code = 'source "$1/lib.sh"; source "$1/alacritty.sh"; alacritty_fingerprint "$2"'
                result = subprocess.run(["/bin/bash", "-c", code, "fixture", str(SCRIPTS), str(self.source)], env=self.env,
                                        text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                failed.unlink()

    def test_install_and_retry_preserve_bundle_and_skip_download(self):
        for _ in range(2):
            result = self.install()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.app / "Contents/MacOS/alacritty").read_bytes(), self.executable.read_bytes())
            self.assertEqual(os.readlink(self.home / ".local/bin/alacritty"), str(self.app / "Contents/MacOS/alacritty"))
        self.assertEqual(self.log.read_text().splitlines(), ["download", "attach", "detach"])
        self.assertFalse(list(self.home.glob("Applications/.dotfiles-alacritty.*")))
        self.assertFalse(list(self.root.glob("dotfiles-alacritty.*")))
        record = self.home / ".local/state/dotfiles/alacritty.sha256"
        self.assertEqual(record.stat().st_mode & 0o777, 0o600)

    def test_checksum_mismatch_never_mounts_or_installs(self):
        self.dmg.write_bytes(b"corrupted download")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["download"])
        self.assertFalse(self.app.exists())

    def test_existing_unknown_or_modified_app_is_not_overwritten(self):
        self.app.parent.mkdir(parents=True)
        shutil.copytree(self.source, self.app)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unowned or modified", result.stderr)
        self.assertFalse(self.log.exists())
        shutil.rmtree(self.app)
        self.assertEqual(self.install().returncode, 0)
        binary = self.app / "Contents/MacOS/alacritty"
        binary.write_text("user modification\n")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(binary.read_text(), "user modification\n")
        self.assertEqual(self.log.read_text().splitlines(), ["download", "attach", "detach"])

    def test_invalid_bundle_is_rejected_and_disk_is_detached(self):
        (self.source / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": "unexpected.app", "CFBundleShortVersionString": "0.17.0"}))
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unexpected app bundle identifier", result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["download", "attach", "detach"])
        self.assertFalse(self.app.exists())

    def test_redirected_cli_is_not_overwritten(self):
        binary = self.home / ".local/bin/alacritty"
        binary.parent.mkdir(parents=True)
        binary.symlink_to(self.home / "another-app")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(os.readlink(binary), str(self.home / "another-app"))
        self.assertFalse(self.log.exists())


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

    def test_tmux_preserves_config_except_agreed_changes(self):
        old = (ROOT / "tmux/tmux.conf").read_text()
        new = (ROOT / "home/dot_config/tmux/tmux.conf").read_text()
        self.assertEqual(old.replace("set -g @plugin 'omerxx/tmux-sessionx'\n", ""),
                         new)
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
