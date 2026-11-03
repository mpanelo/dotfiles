#!/usr/bin/env python3
"""Report public update metadata. Never installs tools or changes repository pins."""
import argparse
import html
import json
import os
from pathlib import Path
import re
import tomllib
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def version(value):
    match = re.fullmatch(r"v?(\d+)\.(\d+)(?:\.(\d+))?", value)
    if not match:
        raise ValueError("Not a stable version")
    return tuple(int(part or 0) for part in match.groups())


def latest(values):
    stable = []
    for value in values:
        try:
            stable.append((version(value), value.removeprefix("v")))
        except ValueError:
            pass
    if not stable:
        raise ValueError("No stable versions in metadata")
    return max(stable)[1]


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, url):
        if urllib.parse.urlsplit(url).scheme != "https":
            raise ValueError("Refusing non-HTTPS redirect")
        redirected = super().redirect_request(request, fp, code, msg, headers, url)
        if urllib.parse.urlsplit(request.full_url).hostname != urllib.parse.urlsplit(url).hostname:
            redirected.remove_header("Authorization")
        return redirected


class Metadata:
    def __init__(self, token=None):
        self.token = token
        self.cache = {}
        self.opener = urllib.request.build_opener(SafeRedirect())

    def text(self, url):
        if urllib.parse.urlsplit(url).scheme != "https":
            raise ValueError("Metadata requires HTTPS")
        if url not in self.cache:
            headers = {"User-Agent": "mpanelo-dotfiles-update-report", "Accept": "application/json"}
            if self.token and urllib.parse.urlsplit(url).hostname == "api.github.com":
                headers["Authorization"] = "Bearer " + self.token
            request = urllib.request.Request(url, headers=headers)
            with self.opener.open(request, timeout=15) as response:
                self.cache[url] = response.read().decode("utf-8")
        return self.cache[url]

    def json(self, url):
        return json.loads(self.text(url))


def github_repo(url):
    match = re.fullmatch(r"https://github.com/([\w.-]+/[\w.-]+?)(?:\.git)?", url)
    if not match:
        raise ValueError("Unsupported plugin source")
    return match[1]


class Report:
    def __init__(self, metadata):
        self.metadata = metadata
        self.rows = []

    def check(self, category, name, declared, source, lookup, kind="version"):
        row = dict(category=category, name=name, declared=declared, source=source)
        try:
            available = lookup()
            if kind == "commit":
                if not re.fullmatch(r"[a-f0-9]{40}", available):
                    raise ValueError("Invalid upstream commit")
                state = "unchanged" if declared == available else "different upstream revision"
            elif kind == "catalog":
                if not isinstance(available, str) or not available:
                    raise ValueError("Missing package metadata")
                state = "catalog; installed Mac versions not compared"
            else:
                state = ("newer available" if version(available) > version(declared) else
                         "unchanged" if version(available) == version(declared) else "declared version ahead of upstream metadata")
            row.update(available=available, status=state)
        except urllib.error.HTTPError as error:
            row.update(available="unknown", status=f"lookup failed (HTTP {error.code})")
            error.close()
        except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError, TypeError, IndexError, AttributeError):
            row.update(available="unknown", status="lookup failed (unavailable or invalid metadata)")
        self.rows.append(row)

    def release(self, name, declared, repo, category="Tools"):
        source = f"https://api.github.com/repos/{repo}/releases/latest"
        self.check(category, name, declared, source,
                   lambda: self.metadata.json(source)["tag_name"].removeprefix("v"))
        self.rows[-1]["review"] = f"https://github.com/{repo}/releases/latest"

    def plugin(self, category, name, declared, repo, branch=None):
        source = (f"https://api.github.com/repos/{repo}/commits/{urllib.parse.quote(branch, safe='')}" if branch else
                  f"https://api.github.com/repos/{repo}/commits?per_page=1")
        self.check(category, name, declared, source,
                   lambda: (self.metadata.json(source) if branch else self.metadata.json(source)[0])["sha"], "commit")
        if self.rows[-1]["available"] != "unknown":
            self.rows[-1]["review"] = f"https://github.com/{repo}/compare/{declared}...{self.rows[-1]['available']}"

    def collect(self, root):
        pins = json.loads((root / "manifests/versions.json").read_text())
        source = "https://go.dev/dl/?mode=json"
        self.check("Tools", "Go", pins["go"], source,
                   lambda: latest(item["version"].removeprefix("go") for item in self.metadata.json(source) if item["stable"]))
        source = "https://static.rust-lang.org/dist/channel-rust-stable.toml"
        self.check("Tools", "Rust", pins["rust"], source,
                   lambda: tomllib.loads(self.metadata.text(source))["pkg"]["rust"]["version"].split()[0])
        source = "https://api.github.com/repos/python/cpython/tags?per_page=100"
        self.check("Tools", "Python runtime", pins["python"], source,
                   lambda: latest(item["name"] for item in self.metadata.json(source)))
        for name in ("basedpyright", "ruff", "nodejs-wheel-binaries"):
            source = f"https://pypi.org/pypi/{name}/json"
            self.check("Tools", name, pins[name], source,
                       lambda source=source: latest(name for name, files in self.metadata.json(source)["releases"].items()
                                                   if files and any(not file.get("yanked", False) for file in files)))
        self.release("Alacritty", pins["alacritty"], "alacritty/alacritty")
        self.release("Tree-sitter CLI", pins["tree-sitter-cli"], "tree-sitter/tree-sitter")
        for line in (root / "manifests/go-tools.tsv").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            name, module, declared = line.split()
            # goimports belongs to the x/tools module, not its cmd subdirectory.
            module = module.split("/cmd/")[0]
            source = f"https://proxy.golang.org/{module}/@v/list"
            self.check("Tools", name, declared, source,
                       lambda source=source: latest(self.metadata.text(source).splitlines()))
        lock = json.loads((root / "home/dot_config/nvim/lazy-lock.json").read_text())
        for line in (root / "manifests/nvim-plugins.tsv").read_text().splitlines():
            if line and not line.startswith("#"):
                name, url = line.split()
                self.plugin("Neovim plugins", name, lock[name]["commit"], github_repo(url), lock[name]["branch"])
        for line in (root / "manifests/tmux-plugins.tsv").read_text().splitlines():
            if line and not line.startswith("#"):
                name, url, declared = line.split()
                self.plugin("tmux plugins", name, declared, github_repo(url))
        for line in (root / "home/dot_config/fish/fish_plugins").read_text().splitlines():
            if line and not line.startswith("#"):
                repo, declared = line.rsplit("@", 1)
                self.plugin("Fish plugins", repo, declared, repo)
        for kind, name in re.findall(r'^(brew|cask) "([^"]+)"', (root / "Brewfile").read_text(), re.M):
            if "/" in name:
                # The tap formula may lag its upstream release; do not equate the two.
                if name == "raine/workmux/workmux":
                    source = "https://api.github.com/repos/raine/workmux/releases/latest"
                    self.check("Homebrew catalog", name + " (upstream release; tap version unverified)", "unlocked", source,
                               lambda: self.metadata.json(source)["tag_name"].removeprefix("v"), "catalog")
                else:
                    self.check("Homebrew catalog", name, "unlocked", "", lambda: None, "catalog")
                continue
            source = f"https://formulae.brew.sh/api/{'formula' if kind == 'brew' else 'cask'}/{name}.json"
            def package(source=source, kind=kind):
                data = self.metadata.json(source)
                value = data["versions"]["stable"] if kind == "brew" else data["version"]
                flags = [flag for flag in ("deprecated", "disabled") if data.get(flag)]
                return value + ("; " + ", ".join(flags) if flags else "")
            self.check("Homebrew catalog", name, "unlocked", source, package, "catalog")

    @property
    def incomplete(self):
        return sum(row["available"] == "unknown" for row in self.rows)

    def markdown(self, baseline="unknown"):
        def cell(value):
            return html.escape(str(value)).replace("|", "\\|").replace("\n", " ").replace("`", "")
        lines = ["# Weekly dependency report", "", f"Current editor integration baseline: **{cell(baseline)}**.",
                 "Available updates are candidates, not a tested combined upgrade. No pins or installed environments were changed.",
                 "Homebrew entries are an upstream version catalog; the Brewfile does not lock versions or describe either Mac's installed versions.",
                 f"Incomplete lookups: **{self.incomplete}**. A failed lookup never means up to date.", ""]
        for category in dict.fromkeys(row["category"] for row in self.rows):
            lines += ["## " + category, "", "| Dependency | Declared | Available | Status |", "| --- | --- | --- | --- |"]
            for row in self.rows:
                if row["category"] != category:
                    continue
                values = [row["name"], row["declared"], row["available"], row["status"]]
                if category.endswith("plugins"):
                    values[1:3] = [v[:12] if re.fullmatch(r"[a-f0-9]{40}", v) else v for v in values[1:3]]
                cells = [cell(v) for v in values]
                link = row.get("review", row["source"])
                if link:
                    cells[0] = f"[{cells[0]}]({link})"
                lines.append("| " + " | ".join(cells) + " |")
            lines.append("")
        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-token-env", help="Explicit CI token environment variable; never logged")
    parser.add_argument("--baseline", choices=("success", "failure", "cancelled", "skipped", "unknown"), default="unknown")
    args = parser.parse_args()
    token = os.environ.get(args.github_token_env) if args.github_token_env else None
    report = Report(Metadata(token))
    report.collect(ROOT)
    text = report.markdown(args.baseline)
    if args.output:
        args.output.write_text(text)
    else:
        print(text)
    raise SystemExit(1 if report.incomplete else 0)


if __name__ == "__main__":
    main()
