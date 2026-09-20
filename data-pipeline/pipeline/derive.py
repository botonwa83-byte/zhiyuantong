"""从投档线派生院校主数据：官方院校代码、所在地、办学性质、层次。"""

from __future__ import annotations

import functools

from pipeline.config import list_provinces, load_province_config


@functools.lru_cache(maxsize=1)
def province_id_by_name() -> dict[str, str]:
    """中文省名 -> 省份 id（如 河南 -> henan），用于把院校所在地归一到 App 的 id 体系。"""
    mapping: dict[str, str] = {}
    for prov_id in list_provinces():
        cfg = load_province_config(prov_id)
        name = getattr(cfg, "name", None)
        if name:
            mapping[name] = prov_id
    return mapping


_TRUE = {"1", "true", "True", "是", "Y"}


def _level(row: dict) -> str:
    if str(row.get("is_985", "")) in _TRUE:
        return "985"
    if str(row.get("is_211", "")) in _TRUE:
        return "211"
    if row.get("nature") == "民办":
        return "民办/独立学院"
    return "普通本科"


def derive_university_rows(rows: list[dict]) -> list[dict]:
    """按 (uni_code, uni_name) 去重，产出 university_meta 行。"""
    names = province_id_by_name()
    seen: dict[tuple[str, str], dict] = {}
    for row in rows:
        name = (row.get("uni_name") or "").strip()
        if not name:
            continue
        code = (row.get("uni_code") or "").strip()
        key = (code, name)
        if key in seen:
            continue
        prov_name = (row.get("uni_prov") or "").strip()
        seen[key] = {
            "uni_code": code,
            "uni_name": name,
            "uni_prov": names.get(prov_name, prov_name),
            "nature": (row.get("nature") or "").strip(),
            "level": _level(row),
        }
    return list(seen.values())
