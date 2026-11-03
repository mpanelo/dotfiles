"""Offline update-report tests. No network, package installation, or user state."""
import hashlib
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest import mock
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_updates", ROOT / "scripts/check_updates.py")
updates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updates)


class PublicMetadataFixture:
    def json(self, url):
        if "/api/formula/" in url:
            return {"versions": {"stable": "3.0.0"}, "disabled": True}
        if "/api/cask/" in url:
            return {"version": "3.0.0"}
        if "go.dev" in url:
            return [{"version": "go1.99.0", "stable": True}, {"version": "go2.0rc1", "stable": False}]
        if "/pypi/" in url:
            return {"releases": {"99.0.0": [{"yanked": False}], "100.0.0": [{"yanked": True}], "101.0.0rc1": [{}]}}
        if "/tags?" in url:
            return [{"name": "v3.99.0"}, {"name": "v4.0.0a1"}]
        if "/releases/latest" in url:
            return {"tag_name": "v99.0.0"}
        if "/commits?" in url:
            return [{"sha": "a" * 40}]
        if "/commits/" in url:
            return {"sha": "a" * 40}
        raise AssertionError("Unspecified fixture URL: " + url)

    def text(self, url):
        if "channel-rust-stable" in url:
            return '[pkg.rust]\nversion = "1.99.0 (fixture)"\n'
        if "proxy.golang.org" in url:
            return "v0.99.0\nv0.100.0-rc1\n"
        raise AssertionError("Unspecified fixture URL: " + url)


class UpdateReportTests(unittest.TestCase):
    def test_stable_version_selection_ignores_prereleases(self):
        self.assertEqual(updates.latest(["v1.9.0", "v1.10.0", "v2.0.0rc1", "invalid"]), "1.10.0")
        with self.assertRaises(ValueError):
            updates.latest(["v2.0.0rc1"])

    def test_complete_report_is_read_only_and_distinguishes_homebrew_catalog(self):
        files = [ROOT / "Brewfile", *list((ROOT / "manifests").glob("*")),
                 ROOT / "home/dot_config/nvim/lazy-lock.json", ROOT / "home/dot_config/fish/fish_plugins"]
        before = {p: hashlib.sha256(p.read_bytes()).digest() for p in files if p.is_file()}
        report = updates.Report(PublicMetadataFixture())
        report.collect(ROOT)
        self.assertEqual(report.incomplete, 0)
        names = {row["name"]: row for row in report.rows}
        self.assertEqual(names["basedpyright"]["available"], "99.0.0")
        self.assertEqual(names["goimports"]["source"], "https://proxy.golang.org/golang.org/x/tools/@v/list")
        self.assertIn("disabled", names["fish"]["available"])
        self.assertEqual(names["fish"]["declared"], "unlocked")
        text = report.markdown("success")
        self.assertIn("not a tested combined upgrade", text)
        self.assertIn("installed Mac versions not compared", text)
        self.assertNotIn("100.0.0", text)
        self.assertEqual(before, {p: hashlib.sha256(p.read_bytes()).digest() for p in before})

    def test_failed_lookups_and_invalid_commits_are_unknown(self):
        report = updates.Report(PublicMetadataFixture())
        def unavailable():
            raise urllib.error.HTTPError("https://api.github.com/fixture", 429, "rate limited", {}, None)
        report.check("Tools", "fixture", "1.0.0", "https://api.github.com/fixture", unavailable)
        report.check("Plugins", "broken commit", "a" * 40, "", lambda: "not-a-commit", "commit")
        self.assertEqual(report.incomplete, 2)
        self.assertTrue(all(row["available"] == "unknown" for row in report.rows))
        self.assertIn("HTTP 429", report.markdown())
        self.assertNotIn("| unchanged |", report.markdown())

    def test_old_upstream_metadata_does_not_recommend_downgrades(self):
        report = updates.Report(PublicMetadataFixture())
        report.check("Tools", "fixture", "3.0.0", "", lambda: "2.0.0")
        self.assertEqual(report.rows[0]["status"], "declared version ahead of upstream metadata")

    def test_markdown_escapes_metadata(self):
        report = updates.Report(PublicMetadataFixture())
        report.check("Tools", "<name>|\nrow", "1.0.0", "", lambda: "2.0.0")
        self.assertIn("&lt;name&gt;\\| row", report.markdown())
        self.assertNotIn("<name>", report.markdown())

    def test_redirect_does_not_forward_authorization_to_another_host(self):
        request = urllib.request.Request("https://api.github.com/fixture", headers={"Authorization": "Bearer fixture"})
        redirect = updates.SafeRedirect().redirect_request(request, None, 302, "Found", {}, "https://example.invalid/target")
        self.assertIsNone(redirect.get_header("Authorization"))
        with self.assertRaises(ValueError):
            updates.SafeRedirect().redirect_request(request, None, 302, "Found", {}, "http://example.invalid/target")

    def test_optional_token_is_only_sent_to_github_api(self):
        metadata = updates.Metadata("fixture-token")
        opener = mock.Mock()
        opener.open.return_value.__enter__ = mock.Mock(return_value=mock.Mock(read=lambda: b"{}"))
        opener.open.return_value.__exit__ = mock.Mock(return_value=False)
        metadata.opener = opener
        metadata.text("https://api.github.com/fixture")
        metadata.text("https://formulae.brew.sh/fixture")
        requests = [call.args[0] for call in opener.open.call_args_list]
        self.assertEqual(requests[0].get_header("Authorization"), "Bearer fixture-token")
        self.assertIsNone(requests[1].get_header("Authorization"))

    def test_cli_publishes_incomplete_report_and_fails(self):
        metadata = mock.Mock()
        metadata.text.side_effect = urllib.error.URLError("fixture unavailable")
        metadata.json.side_effect = urllib.error.URLError("fixture unavailable")
        output = io.StringIO()
        with mock.patch.object(updates, "Metadata", return_value=metadata), mock.patch("sys.argv", ["check_updates.py"]):
            with contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as result:
                updates.main()
        self.assertEqual(result.exception.code, 1)
        self.assertIn("lookup failed", output.getvalue())
        self.assertNotIn("| unchanged |", output.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
