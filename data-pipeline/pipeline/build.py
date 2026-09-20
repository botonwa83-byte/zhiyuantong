"""产物生成：把 staging 的院校主数据导出为 App 可直接导入的院校库 CSV。

内置院校（App 手工标注的 104 所）优先：其人工参数（线差、保研率、就业等）保留不动，
官方数据只补充其缺失的代码/层次/性质；其余院校以官方数据入库，人工参数留空由 App 降级展示。
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import pandas as pd

STAGING_DIR = Path(__file__).resolve().parent.parent / "staging"
DIST_DIR = Path(__file__).resolve().parent.parent / "dist"

# App 导入表头（与 UniversitySeed 对齐；缺失即空，由 App 端降级展示）
OUTPUT_COLUMNS = [
    "uni_code",
    "name",
    "prov",
    "city",
    "level",
    "kind",
    "nature",
]

LEVEL_ORDER = {"顶尖985": 0, "985": 1, "211": 2, "双一流": 3, "省重点": 4, "普通本科": 5, "民办/独立学院": 6}


def build_universities(
    staging_dir: Path = STAGING_DIR,
    dist_dir: Path = DIST_DIR,
    builtin_csv: Path | None = None,
) -> Path:
    src = staging_dir / "university_meta.csv"
    if not src.exists():
        raise SystemExit(f"缺少 {src}，请先跑 pipeline.run")

    official = pd.read_csv(src, dtype=str).fillna("")
    official["_rank"] = official["level"].map(LEVEL_ORDER).fillna(9)
    official = official.sort_values(["_rank", "uni_name"])

    merged: dict[str, dict] = {}
    if builtin_csv and builtin_csv.exists():
        with builtin_csv.open(encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                name = (row.get("name") or "").strip()
                if not name:
                    continue
                merged[name] = {c: (row.get(c) or "").strip() for c in OUTPUT_COLUMNS}

    for _, row in official.iterrows():
        name = str(row["uni_name"]).strip()
        if not name:
            continue
        entry = merged.setdefault(name, {c: "" for c in OUTPUT_COLUMNS})
        # 官方数据只补空位，不覆盖 App 内置标注
        entry["uni_code"] = entry["uni_code"] or str(row["uni_code"]).strip()
        entry["prov"] = entry["prov"] or str(row["uni_prov"]).strip()
        entry["level"] = entry["level"] or str(row["level"]).strip()
        entry["nature"] = entry["nature"] or str(row["nature"]).strip()

    dist_dir.mkdir(parents=True, exist_ok=True)
    out = dist_dir / "universities_full.csv"
    with out.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        for name in sorted(merged):
            row = merged[name]
            row.setdefault("name", name)
            if not row["name"]:
                row["name"] = name
            writer.writerow({c: row.get(c, "") for c in OUTPUT_COLUMNS})
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="生成 App 院校库产物")
    parser.add_argument("--staging", default=str(STAGING_DIR))
    parser.add_argument("--dist", default=str(DIST_DIR))
    parser.add_argument("--builtin", default="", help="App 内置院校 CSV（name,prov,city,level,kind,nature,uni_code）")
    args = parser.parse_args()

    out = build_universities(Path(args.staging), Path(args.dist), Path(args.builtin) if args.builtin else None)
    rows = sum(1 for _ in out.open(encoding="utf-8")) - 1
    print(f"已生成 {out}（{rows} 所院校）")


if __name__ == "__main__":
    main()
