"""院校名规范化：官方名 ←→ App 内名。匹配不到的进复核队列。

索引按文件 mtime 缓存，长跑进程内更新别名表也能生效。
只做「全等 / 去括号后缀」两级匹配，不做后缀剥离，避免「郑州学院」被并进「郑州大学」。
"""

from __future__ import annotations

import re
from pathlib import Path

import pandas as pd

ALIAS_PATH = Path(__file__).resolve().parent.parent / "configs" / "university_aliases.csv"

_BRACKETS = re.compile(r"[（(][^）)]*[）)]")

_cache: dict[tuple[str, float], dict[str, str]] = {}


def clean_name(raw: str) -> str:
    text = str(raw).strip()
    text = text.translate(str.maketrans("０１２３４５６７８９（）　", "0123456789() "))
    return re.sub(r"\s+", "", text)


def _variants(name: str) -> list[str]:
    base = clean_name(name)
    return [base, _BRACKETS.sub("", base)]


def _build_index(path: Path) -> dict[str, str]:
    df = pd.read_csv(path, encoding="utf-8-sig", keep_default_na=False)
    index: dict[str, str] = {}
    for _, row in df.iterrows():
        canonical = clean_name(row["uni_name"])
        if not canonical:
            continue
        for variant in _variants(canonical) + [clean_name(a) for a in str(row.get("aliases", "") or "").split("|") if a]:
            index.setdefault(variant, canonical)
    return index


def _index() -> dict[str, str]:
    if not ALIAS_PATH.exists():
        return {}
    key = (str(ALIAS_PATH), ALIAS_PATH.stat().st_mtime)
    if key not in _cache:
        _cache.clear()
        _cache[key] = _build_index(ALIAS_PATH)
    return _cache[key]


def canonical_name(raw: str) -> str | None:
    index = _index()
    if not index:
        return None
    for variant in _variants(raw):
        hit = index.get(variant)
        if hit:
            return hit
    return None
