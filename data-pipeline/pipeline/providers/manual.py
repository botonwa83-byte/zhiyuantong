"""人工兜底解析器：扫描件合订本 / 已下线页面的最后手段，读 manual/ 下填好的 CSV。"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


def parse_manual(path: Path, options: dict) -> tuple[list[dict], int]:
    df = pd.read_csv(Path(path), encoding="utf-8-sig", dtype=str).dropna(how="all")
    rows = [
        {k: str(v).strip() for k, v in rec.items() if str(v).strip() and str(v).strip().lower() != "nan"}
        for rec in df.to_dict("records")
    ]
    return rows, 0
