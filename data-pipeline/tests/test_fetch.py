import time
from pathlib import Path

import pytest

from pipeline import fetch as fetch_mod
from pipeline.config import SourceSpec
from pipeline.fetch import archive_path, fetch_source, resolve_url

FIXTURE = Path(__file__).parent / "fixtures" / "sample_table.html"


class _Resp:
    content = b"<html>ok</html>"

    def raise_for_status(self):
        return None


def _spec(url="https://example.org/{year}/rank.html"):
    return SourceSpec("rank_table", url, "html_table")


def test_resolve_url_replaces_year():
    assert resolve_url(_spec(), 2025) == "https://example.org/2025/rank.html"


def test_file_url_returns_local_path():
    path = fetch_source(_spec(f"file:{FIXTURE}"), 2025)
    assert path.exists()
    assert path.read_text(encoding="utf-8")


def test_offline_mode_raises_when_no_archive(monkeypatch, tmp_path):
    monkeypatch.setattr(fetch_mod, "OFFLINE", True)
    monkeypatch.setattr(fetch_mod, "RAW_DIR", tmp_path)
    with pytest.raises(RuntimeError, match="离线模式"):
        fetch_source(_spec(), 2025, "henan")


def test_robots_disallowed_raises(monkeypatch, tmp_path):
    monkeypatch.setattr(fetch_mod, "RAW_DIR", tmp_path)
    monkeypatch.setattr(fetch_mod, "OFFLINE", False)
    monkeypatch.setattr(fetch_mod, "_robots_allows", lambda url: False)
    with pytest.raises(RuntimeError, match="robots.txt"):
        fetch_source(_spec(), 2025, "henan")


def test_rate_limit_sleeps_between_requests(monkeypatch, tmp_path):
    slept: list[float] = []
    monkeypatch.setattr(fetch_mod, "RAW_DIR", tmp_path)
    monkeypatch.setattr(fetch_mod, "OFFLINE", False)
    monkeypatch.setattr(fetch_mod, "_robots_allows", lambda url: True)
    monkeypatch.setattr(fetch_mod, "_last_hit", {"example.org": time.monotonic()})
    monkeypatch.setattr(fetch_mod.time, "sleep", lambda s: slept.append(s))
    monkeypatch.setattr(fetch_mod.requests, "get", lambda *a, **k: _Resp())

    fetch_source(_spec(), 2025, "henan")
    assert slept, "同一域名连续请求之间必须限速"
    assert slept[0] > 0


def test_response_is_archived_and_reused(monkeypatch, tmp_path):
    calls: list[str] = []
    monkeypatch.setattr(fetch_mod, "RAW_DIR", tmp_path)
    monkeypatch.setattr(fetch_mod, "OFFLINE", False)
    monkeypatch.setattr(fetch_mod, "_robots_allows", lambda url: True)
    monkeypatch.setattr(fetch_mod, "_last_hit", {})
    monkeypatch.setattr(fetch_mod.time, "sleep", lambda s: None)
    monkeypatch.setattr(
        fetch_mod.requests, "get", lambda url, **k: (calls.append(url), _Resp())[1]
    )

    first = fetch_source(_spec(), 2025, "henan")
    second = fetch_source(_spec(), 2025, "henan")
    assert len(calls) == 1, "第二次必须命中存档而不是重新请求"
    assert first == second
    assert (tmp_path / "henan" / "2025").exists()


def test_different_query_strings_do_not_share_archive():
    a = archive_path("https://x.org/rank.html?track=phy", "rank_table", 2025, "henan")
    b = archive_path("https://x.org/rank.html?track=his", "rank_table", 2025, "henan")
    assert a != b
