"""人工兜底解析器：扫描件合订本 / 已下线页面的最后手段，读 manual/ 下填好的 CSV。"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


def parse_manual(path: Path, options: dict) -> tuple[list[dict], int]:
    path = Path(path)
    # 人工副本有时取回来的是反爬 HTML 页面（看着像 CSV 文件，其实是网页），
    # 直接喂给 read_csv 会解析出一堆垃圾行，这里先挡掉并说清原因。
    head = path.open("rb").read(512).decode("utf-8", errors="ignore").lstrip().lower()
    if head.startswith("<!doctype") or head.startswith("<html"):
        raise ValueError("源文件不是 CSV（取回的是 HTML 页面，多半是被反爬拦截）——请人工导出后覆盖")
    df = pd.read_csv(path, encoding="utf-8-sig", dtype=str).dropna(how="all")
    rows = [
        {k: str(v).strip() for k, v in rec.items() if str(v).strip() and str(v).strip().lower() != "nan"}
        for rec in df.to_dict("records")
    ]
    return rows, 0
