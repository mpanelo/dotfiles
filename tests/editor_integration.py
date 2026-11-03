#!/usr/bin/env python3
"""Build pinned editor plugins and exercise real LSPs in a private temporary HOME.

Requires existing macOS binaries: chezmoi, git, nvim, go, uv, jq, rg, fd,
lua-language-server, and stylua. Downloads tools only into the private workspace;
never installs Homebrew packages, applies live dotfiles, or changes the login shell.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

from test_chezmoi_integration import Harness, ROOT, cleanup_workspace, live_metadata


CASES = [
    {"language": "go", "file": "main.go", "client": "gopls", "call_line": 4,
     "diagnostic_line": 3, "formatted": "func answer() int { return 42 }",
     "files": {"go.mod": "module example.invalid/editorfixture\n\ngo 1.26\n",
               "main.go": 'package fixture\n\nfunc answer() int{return 42}\nfunc broken() int{return "wrong"}\nfunc use() int{return answer()}\n'}},
    {"language": "rust", "file": "src/main.rs", "client": "rust", "call_line": 1,
     "formatted": "fn answer() -> i32 {",
     "files": {"Cargo.toml": '[package]\nname="editor-fixture"\nversion="0.1.0"\nedition="2021"\n',
               "src/main.rs": 'fn answer()->i32{42}\nfn main(){let _value=answer();}\n'}},
    {"language": "lua", "file": "main.lua", "client": "lua_ls", "call_line": 3,
     "diagnostic_line": 2, "formatted": "local value = answer()",
     "files": {".luarc.json": '{"runtime":{"version":"LuaJIT"},"workspace":{"checkThirdParty":false}}\n',
               "main.lua": 'local function answer() return 42 end\n---@type number\nlocal count = "wrong"\nlocal value=answer()\nreturn value\n'}},
    {"language": "python", "file": "main.py", "client": "basedpyright", "call_line": 3,
     "diagnostic_line": 2, "formatted": "value = answer()",
     "files": {"pyrightconfig.json": '{"typeCheckingMode":"basic","include":["main.py"]}\n',
               "main.py": 'def answer() -> int:\n    return 42\ncount: int = "wrong"\nvalue=answer()\n'}},
]


class EditorHarness(Harness):
    def prepare(self):
        self.deployment_checks()
        self.bin = self.workspace / "bin"
        self.bin.mkdir()
        # Link only declared prerequisites. The runner's Node/npm and user tools
        # must not accidentally satisfy a missing editor runtime.
        for name in ("git", "nvim", "go", "uv", "jq", "rg", "fd", "lua-language-server", "stylua"):
            executable = Path("/opt/homebrew/bin") / name
            if not executable.is_file() or not os.access(executable, os.X_OK):
                raise RuntimeError(f"Required test prerequisite is missing: {name}")
            (self.bin / name).symlink_to(executable)
        self.env.update({
            "XDG_CONFIG_HOME": str(self.destination / ".config"),
            "XDG_DATA_HOME": str(self.fake_home / ".local/share"),
            "XDG_STATE_HOME": str(self.fake_home / ".local/state"),
            "XDG_CACHE_HOME": str(self.fake_home / ".cache"),
            "CARGO_HOME": str(self.fake_home / ".cargo"),
            "RUSTUP_HOME": str(self.fake_home / ".rustup"),
            "GOPATH": str(self.fake_home / "go"),
            "GOBIN": str(self.fake_home / "go/bin"),
            "GOCACHE": str(self.workspace / "go-cache"),
            "UV_TOOL_DIR": str(self.fake_home / ".local/share/uv/tools"),
            "UV_TOOL_BIN_DIR": str(self.fake_home / ".local/bin"),
            "UV_CACHE_DIR": str(self.workspace / "uv-cache"),
            "UV_PYTHON_INSTALL_DIR": str(self.workspace / "python"),
            "GIT_ALLOW_PROTOCOL": "https:file",
            "DOTFILES_VERIFY_ONLY": "1", "DOTFILES_PROVISIONING": "1",
            "DOTFILES_REPO_ROOT": str(self.source),
        })
        self.env["PATH"] = os.pathsep.join(map(str, [self.fake_home / ".local/bin", self.fake_home / ".cargo/bin",
                                                    self.fake_home / "go/bin", self.bin,
                                                    "/usr/bin", "/bin", "/usr/sbin", "/sbin"]))
        self.versions = json.loads((self.source / "manifests/versions.json").read_text())
        self.env["GOTOOLCHAIN"] = "go" + self.versions["go"]
        self.env["RUSTUP_TOOLCHAIN"] = self.versions["rust"]

    def tools(self):
        print("Preparing isolated Go, Rust, and uv editor tools", flush=True)
        for line in (self.source / "manifests/go-tools.tsv").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            _, module, version = line.split()
            self.run(["go", "install", module + "@" + version], timeout=600)
        installer = self.workspace / "rustup-init"
        # Reuse checksum verification, never the production reconciliation entry point.
        self.run(["/bin/bash", "-c", 'source "$1/scripts/bootstrap/lib.sh"; download_installer "rustup-$(uname -m)" "$2"',
                  "fixture", self.source, installer])
        self.run(["lipo", installer, "-verify_arch", platform.machine()])
        installer.chmod(0o700)
        self.run([installer, "-y", "--no-modify-path", "--default-toolchain", "none", "--profile", "minimal"], timeout=300)
        self.run(["rustup", "toolchain", "install", self.versions["rust"], "--profile", "minimal",
                  "--component", "rust-analyzer,rustfmt,rust-src", "--no-self-update"], timeout=600)
        for name in ("basedpyright", "ruff"):
            self.run(["uv", "--no-config", "tool", "install", "--managed-python", "--python", self.versions["python"],
                      "--no-build", "--constraints", self.source / "manifests/python-tools.constraints.txt",
                      name + "==" + self.versions[name]], timeout=300)
        self.run(["/bin/bash", "-c", 'source "$1/scripts/bootstrap/lib.sh"; source "$1/scripts/bootstrap/tree-sitter.sh"; install_tree_sitter',
                  "fixture", self.source], timeout=180)

    def plugins(self):
        print("Fetching pinned plugins and building native libraries and parsers from source", flush=True)
        for line in (self.source / "manifests/nvim-plugins.tsv").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            name, url = line.split()
            lock = json.loads((self.source / "home/dot_config/nvim/lazy-lock.json").read_text())[name]
            target = self.fake_home / ".local/share/nvim/lazy" / name
            self.run(["/bin/bash", "-c", 'source "$1/scripts/bootstrap/lib.sh"; sync_checkout "$2" "$3" "$4" "$5"',
                      "fixture", self.source, target, url, lock["commit"], lock["branch"]], timeout=180)
        lockfile = self.destination / ".config/nvim/lazy-lock.json"
        original = lockfile.read_bytes()
        for script, flags in (("install-blink.lua", ["-u", "NONE"]), ("install-editor.lua", [])):
            code = 'lua dofile(vim.env.DOTFILES_REPO_ROOT .. "/scripts/bootstrap/' + script + '")'
            self.run(["nvim", "--headless", "-i", "NONE", "-n", *flags, "-c", code], timeout=1200)
        assert original == lockfile.read_bytes(), "Native builds changed the plugin lockfile"
        self.passed("fresh native builds and configured parsers load without changing pins")

    def languages(self):
        for case in CASES:
            print("Testing real " + case["language"] + " editor integration", flush=True)
            project = self.workspace / "projects" / case["language"]
            project.mkdir(parents=True)
            for relative, text in case["files"].items():
                file = project / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(text)
            env = dict(self.env, DOTFILES_EDITOR_PROJECT=str(project),
                       DOTFILES_EDITOR_CASE=json.dumps({key: value for key, value in case.items() if key != "files"}),
                       DOTFILES_EDITOR_TEST=str(ROOT / "tests/editor-integration.lua"))
            startup = "lua vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function() vim.schedule(function() dofile(vim.env.DOTFILES_EDITOR_TEST) end) end })"
            capture = "lua _G.dotfiles_startup_errors = {}; local notify = vim.notify; vim.notify = function(msg, level, opts) if level == vim.log.levels.ERROR then table.insert(_G.dotfiles_startup_errors, tostring(msg)) end; return notify(msg, level, opts) end"
            result = self.run(["nvim", "--headless", "-i", "NONE", "-n", "--cmd", capture, "-c", startup], env=env, timeout=300)
            assert "DOTFILES_EDITOR_CASE_OK" in result.stdout, result.stderr
            self.passed(case["language"] + ": real attachment, completion, definition and format-on-save")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-workspace", action="store_true")
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("This integration runner requires Apple Silicon macOS")
    chezmoi = shutil.which("chezmoi")
    if not chezmoi:
        parser.error("chezmoi must already be installed")
    workspace = Path(tempfile.mkdtemp(prefix="dotfiles-editor-test-"))
    before = live_metadata(Path.home())
    try:
        harness = EditorHarness(workspace, Path(chezmoi))
        harness.prepare()
        harness.tools()
        harness.plugins()
        harness.languages()
        print(json.dumps({"passed": len(harness.checks), "checks": harness.checks}, indent=2))
    finally:
        assert before == live_metadata(Path.home()), "Live configuration metadata changed"
        if args.keep_workspace:
            print("Private integration workspace:", workspace, flush=True)
        else:
            cleanup_workspace(workspace)


if __name__ == "__main__":
    main()
