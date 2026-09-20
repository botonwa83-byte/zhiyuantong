"""Excel 解析器：省站发布 .xls / .xlsx 投档线时使用。"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from pipeline.providers.base import apply_column_map


def parse_xls(path: Path, options: dict) -> tuple[list[dict], int]:
    df = pd.read_excel(Path(path), sheet_name=options.get("sheet", 0), header=None, dtype=str)
    df = df.dropna(how="all")
    if df.empty:
        return [], 0

    header_row = options.get("header_row", 0)
    headers = [str(h) for h in df.iloc[header_row].tolist()]
    body = [[str(v) for v in rec] for rec in df.iloc[header_row + 1 :].values.tolist()]
    return apply_column_map(headers, body, options.get("column_map"), list(options.get("columns", [])))
