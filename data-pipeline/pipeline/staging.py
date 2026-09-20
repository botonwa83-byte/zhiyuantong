"""staging CSV 读写：人工可审阅、diff 友好的中间层。"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from pipeline.contract import TABLES


def table_path(kind: str, staging_dir: Path) -> Path:
    return Path(staging_dir) / f"{kind}.csv"


def write_table(df: pd.DataFrame, kind: str, staging_dir: Path) -> Path:
    spec = TABLES[kind]
    missing = [c for c in spec.required if c not in df.columns]
    if missing:
        raise ValueError(f"{kind} 缺少必需列: {missing}")
    out = df.reindex(columns=list(spec.columns))
    Path(staging_dir).mkdir(parents=True, exist_ok=True)
    path = table_path(kind, staging_dir)
    out.to_csv(path, index=False, encoding="utf-8")
    return path


def read_table(kind: str, staging_dir: Path) -> pd.DataFrame:
    path = table_path(kind, staging_dir)
    if not path.exists():
        return pd.DataFrame(columns=list(TABLES[kind].columns))
    return pd.read_csv(path, encoding="utf-8")
