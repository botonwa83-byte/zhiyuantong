"""抓取层：限速、遵守 robots.txt、原始页存档到 raw/<prov>/<year>/。"""

from __future__ import annotations

import hashlib
import os
import time
from pathlib import Path
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import requests

from pipeline.config import SourceSpec

RAW_DIR = Path(os.environ.get("GAOKAO_RAW_DIR", Path(__file__).resolve().parent.parent / "raw"))
OFFLINE = os.environ.get("GAOKAO_OFFLINE") == "1"
UA = "zhiyuantong-data-pipeline/0.1 (educational use; local)"
MIN_INTERVAL = 1.0

_last_hit: dict[str, float] = {}
_robots: dict[str, RobotFileParser | None] = {}


def resolve_url(spec: SourceSpec, year: int) -> str:
    overrides = getattr(spec, "url_overrides", None) or {}
    template = overrides.get(str(year)) or overrides.get(year) or spec.url_template
    return template.format(year=year)


def archive_path(url: str, kind: str, year: int, prov_id: str = "unknown") -> Path:
    """文件名含完整 URL 摘要，避免仅 query 不同的两个来源串档。"""
    parsed = urlparse(url)
    digest = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12]
    base = Path(parsed.path).name or "index.html"
    return RAW_DIR / prov_id / str(year) / f"{kind}_{digest}_{base}"


def _robots_allows(url: str) -> bool:
    host = urlparse(url).netloc
    if host not in _robots:
        rp = RobotFileParser()
        rp.set_url(f"{urlparse(url).scheme}://{host}/robots.txt")
        try:
            rp.read()
            _robots[host] = rp
        except Exception:
            _robots[host] = None  # 取不到 robots 视为不限制，但结果要缓存
    rp = _robots[host]
    return True if rp is None else rp.can_fetch(UA, url)


def fetch_source(spec: SourceSpec, year: int, prov_id: str = "unknown", force: bool = False) -> Path:
    url = resolve_url(spec, year)
    if url.startswith("file:"):
        local = Path(url.removeprefix("file:"))
        return local if local.is_absolute() else Path.cwd() / local

    dest = archive_path(url, spec.kind, year, prov_id)
    if dest.exists() and not force:
        return dest
    if OFFLINE:
        raise RuntimeError(f"离线模式下缺少存档: {url} -> {dest}")
    if not _robots_allows(url):
        raise RuntimeError(f"robots.txt 禁止抓取: {url}")

    host = urlparse(url).netloc
    gap = time.monotonic() - _last_hit.get(host, 0.0)
    if gap < MIN_INTERVAL:
        time.sleep(MIN_INTERVAL - gap)
    resp = requests.get(url, headers={"User-Agent": UA}, timeout=30)
    resp.raise_for_status()
    _last_hit[host] = time.monotonic()

    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(resp.content)
    return dest
