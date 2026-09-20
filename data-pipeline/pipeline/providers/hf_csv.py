"""GaokaoCompass 数据集（MIT 授权）CSV 解析器。

合规约定：数据集托管站点不允许自动抓取（robots Disallow: /），因此
本解析器**只读取人工下载到 raw/ 的本地副本**；缺失时给出下载指引而不是去抓。
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from pipeline.providers.base import MissingArchive, apply_column_map, local_dataset_path


def dataset_path(kind: str, year: int, prov_id: str, dataset: str) -> Path:
    return local_dataset_path(kind, year, prov_id, dataset, "csv")


def ensure_local(url: str, dest: Path) -> Path:
    if dest.exists():
        return dest
    raise MissingArchive(f"缺少本地副本，请手动下载 {url} 到 {dest}")


def parse_hf_csv(path: Path, options: dict) -> tuple[list[dict], int]:
    df = pd.read_csv(Path(path), dtype=str, encoding="utf-8-sig").dropna(how="all")
    if df.empty:
        return [], 0
    headers = list(df.columns)
    body = [[str(v) for v in rec] for rec in df.values.tolist()]
    rows, dropped = apply_column_map(headers, body, options.get("column_map"), list(options.get("columns", [])))

    # 专业组标识可能缺失，用选科要求兜底，避免同一院校多条投档线被判为重复
    for target, source in (options.get("fallback_columns") or {}).items():
        for row in rows:
            if not row.get(target) and row.get(source):
                row[target] = row[source]

    track_filter = options.get("track_filter")
    if track_filter:
        rows = [r for r in rows if not r.get("track") or any(k in r["track"] for k in track_filter)]
    batch_filter = options.get("batch_filter")
    if batch_filter:
        rows = [r for r in rows if not r.get("batch") or any(k in r["batch"] for k in batch_filter)]
    return rows, dropped
