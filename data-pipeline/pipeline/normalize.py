"""把解析器输出的行归一到契约表：清洗、补上下文、规范名称。"""

from __future__ import annotations

from datetime import datetime, timezone

import pandas as pd

from pipeline.aliases import canonical_name, clean_name
from pipeline.contract import TABLES
from pipeline.providers.base import COLUMN_KEYS, match_columns

TRACK_MAP = {
    "phy": ["物理", "理科", "理工", "物理类"],
    "his": ["历史", "文史", "文科", "历史类"],
}
# 「综合」只在 3+3 省份才是唯一轨；3+1+2 省份出现「文科综合」时不能被判成 phy。
COMBINED_KEYS = ["综合", "综合类"]
VALID_TRACKS = {"phy", "his"}

INT_COLUMNS = {
    "year", "score", "rank", "cum_count", "min_score", "min_rank", "plan", "uni_code",
    "special", "undergrad", "college", "candidates", "ug_plan",
}

ALIASES = {
    "uni": "uni_name",
    "prov": "prov_id",
}

KIND_RENAME = {
    "admission": {"score": "min_score", "rank": "min_rank"},
    "major_admission": {"score": "min_score", "rank": "min_rank"},
}


def normalize_track(value: str, default: str, mode: str | None = None) -> str:
    text = str(value or "").strip()
    if mode == "3+3" and (not text or any(k in text for k in COMBINED_KEYS)):
        return "phy"
    for canon, keys in TRACK_MAP.items():
        if any(k in text for k in keys):
            return canon
    if default in VALID_TRACKS:
        return default
    raise ValueError(f"无法判定科类: {value!r}（default={default!r}）")


def to_int(value) -> object:
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return pd.NA
    text = str(value).strip().translate(str.maketrans("０１２３４５６７８９，", "0123456789,"))
    text = text.replace(",", "").replace(" ", "")
    if not text:
        return pd.NA
    try:
        return int(float(text))
    except ValueError:
        return pd.NA


def _rename_keys(row: dict, wanted: list[str]) -> dict:
    keys = list(row.keys())
    mapping = match_columns(keys, wanted)
    out = {canon: row[keys[idx]] for canon, idx in mapping.items()}
    for key in keys:
        if key in wanted and key not in out:
            out[key] = row[key]
    return out


def normalize_rows(
    rows: list[dict],
    kind: str,
    prov_id: str,
    year: int,
    track: str,
    source: str,
    mode: str | None = None,
) -> pd.DataFrame:
    columns = list(TABLES[kind].columns)
    # 契约列本身必须保留（如 group 不在 COLUMN_KEYS 里），再补短名兜底
    wanted = list(columns) + [k for k in ALIASES if k not in columns] + ["score", "rank"]
    fetched_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    records: list[dict] = []

    for row in rows:
        item = _rename_keys(row, wanted)
        item = {ALIASES.get(k, k): v for k, v in item.items()}
        item["prov_id"] = prov_id
        item["year"] = year
        item["track"] = normalize_track(item.get("track"), track, mode)
        item["source"] = source
        item["fetched_at"] = fetched_at

        for src, dst in KIND_RENAME.get(kind, {}).items():
            if src in item and dst not in item:
                item[dst] = item.pop(src)

        raw_name = item.get("uni_name")
        if raw_name:
            if "uni_raw" in columns:
                item["uni_raw"] = str(raw_name).strip()
            item["uni_name"] = canonical_name(raw_name) or clean_name(raw_name)

        for col in list(item):
            if col in INT_COLUMNS:
                item[col] = to_int(item[col])
        records.append(item)

    return pd.DataFrame(records, columns=columns)
