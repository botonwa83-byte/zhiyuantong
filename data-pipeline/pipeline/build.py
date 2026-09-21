"""产物生成：把 staging 数据导出成 App 可直接导入的 CSV。

1) 院校库 universities_full.csv：内置院校的人工参数优先，官方数据只补空位；
2) app_import/ 下的一分一段表、院校投档线、专业录取线：表头与 App 导入页模板一致，
   用户把文件传进手机即可「我的 → 官方数据接入 → 导入」。
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import pandas as pd

from pipeline.config import CONFIG_DIR, load_province_config

STAGING_DIR = Path(__file__).resolve().parent.parent / "staging"
DIST_DIR = Path(__file__).resolve().parent.parent / "dist"

# App 导入页模板表头（改这里前先同步 DataImportView 的 template 与 Dataset.swift 的 ColumnKey）
RANK_COLUMNS = ["分数", "位次", "省份", "年份", "科类"]
ADMISSION_COLUMNS = ["院校名称", "省份", "科类", "年份", "批次", "最低分", "最低位次", "招生计划"]
MAJOR_COLUMNS = ["院校名称", "专业名称", "科类", "年份", "最低分", "最低位次", "计划数", "选科要求"]

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
        entry["uni_code"] = entry["uni_code"] or _clean_code(str(row["uni_code"]))
        entry["prov"] = entry["prov"] or _province_label(str(row["uni_prov"]).strip())
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


def _clean_code(value: str) -> str:
    """CSV 往返会把整数代码写成 '1761.0'，导出前还原。"""
    v = (value or "").strip()
    if v.endswith(".0") and v[:-2].isdigit():
        return v[:-2]
    return v


def _province_label(value: str) -> str:
    """院校属地可能是 prov_id（heilongjiang）也可能是中文名，统一成中文名。"""
    if not value:
        return ""
    try:
        cfg = load_province_config(value)
    except (FileNotFoundError, KeyError):
        return value
    return cfg.name


def _province_name(prov_id: str) -> str:
    """prov_id（henan）→ 省份中文名（河南）：App 导入时按名称匹配省份。"""
    try:
        return load_province_config(prov_id).name
    except (FileNotFoundError, KeyError):
        return prov_id


def _track_label(track: str, prov_id: str) -> str:
    """管道内部用 phy/his，导给 App 时写成各省自己的科类名，App 按名称识别。"""
    try:
        mode = load_province_config(prov_id).mode
    except (FileNotFoundError, KeyError):
        mode = "3+1+2"
    is_phy = str(track).strip().lower() in {"phy", "物理", "物理类", "理科", "理工"}
    if mode == "3+3":
        return "综合"
    if mode.startswith("文理"):
        return "理科" if is_phy else "文科"
    return "物理类" if is_phy else "历史类"


def _num(value) -> str:
    """去掉 600.0 这类浮点尾巴，App 侧按数字解析。"""
    if value is None or value == "":
        return ""
    try:
        f = float(value)
    except (TypeError, ValueError):
        return str(value).strip()
    if f != f:  # NaN
        return ""
    return str(int(f)) if f.is_integer() else str(round(f, 2))


def _write_csv(rows: list[dict], columns: list[str], path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({c: row.get(c, "") for c in columns})
    return len(rows)


def _read_staging(kind: str, staging_dir: Path, prov_id: str = "") -> pd.DataFrame:
    """读 staging 表；给 prov_id 时只留该省的行（全量批跑后 staging 是 29 省共享的）。"""
    path = staging_dir / f"{kind}.csv"
    if not path.exists():
        return pd.DataFrame()
    df = pd.read_csv(path, dtype=str, encoding="utf-8").fillna("")
    if prov_id and "prov_id" in df.columns:
        df = df[df["prov_id"].astype(str).str.strip() == prov_id]
    return df


def build_rank_export(staging_dir: Path, dist_dir: Path, prov_id: str) -> Path | None:
    df = _read_staging("rank_table", staging_dir, prov_id)
    if df.empty:
        return None
    name = _province_name(prov_id)
    rows = [
        {
            "分数": _num(r["score"]),
            "位次": _num(r["rank"]),
            "省份": name,
            "年份": _num(r["year"]),
            "科类": _track_label(r["track"], prov_id),
        }
        for _, r in df.iterrows()
    ]
    rows.sort(key=lambda x: (x["年份"], x["科类"], -(float(x["分数"] or 0))))
    out = dist_dir / "app_import" / f"{prov_id}_rank.csv"
    _write_csv(rows, RANK_COLUMNS, out)
    return out


def build_admission_export(staging_dir: Path, dist_dir: Path, prov_id: str) -> Path | None:
    """投档线按「省份+年份+科类+批次+院校」聚合：批次必须留在分组键里，同一院校常同时出现在本科批与专科批，
    跨批次取最低分会把专科线当院校线（如河北科技工程职业技术大学 本科批 500 / 专科批 392）。专业组内仍取最低分。"""
    df = _read_staging("admission", staging_dir, prov_id)
    if df.empty:
        return None
    name = _province_name(prov_id)
    grouped: dict[tuple, dict] = {}
    for _, r in df.iterrows():
        key = (
            str(r["year"]).strip(),
            str(r["track"]).strip(),
            str(r.get("batch") or "").strip(),
            str(r["uni_name"]).strip(),
        )
        item = grouped.setdefault(key, {"score": None, "rank": None, "plan": 0.0})
        score = pd.to_numeric(r.get("min_score"), errors="coerce")
        if pd.notna(score) and (item["score"] is None or score < item["score"]):
            item["score"] = float(score)
            rank = pd.to_numeric(r.get("min_rank"), errors="coerce")
            item["rank"] = float(rank) if pd.notna(rank) else None
        plan = pd.to_numeric(r.get("plan"), errors="coerce")
        if pd.notna(plan):
            item["plan"] += float(plan)
    rows = [
        {
            "院校名称": uni,
            "省份": name,
            "科类": _track_label(track, prov_id),
            "年份": _num(year),
            "批次": batch,
            "最低分": _num(item["score"]),
            "最低位次": _num(item["rank"]) if item["rank"] else "",
            "招生计划": _num(item["plan"]) if item["plan"] else "",
        }
        for (year, track, batch, uni), item in grouped.items()
    ]
    rows.sort(key=lambda x: (x["年份"], x["科类"], -(float(x["最低分"] or 0))))
    out = dist_dir / "app_import" / f"{prov_id}_admission.csv"
    _write_csv(rows, ADMISSION_COLUMNS, out)
    return out


def build_major_export(staging_dir: Path, dist_dir: Path, prov_id: str) -> Path | None:
    df = _read_staging("major_admission", staging_dir, prov_id)
    if df.empty:
        return None
    name = _province_name(prov_id)
    rows = [
        {
            "院校名称": str(r["uni_name"]).strip(),
            "专业名称": str(r["major_name"]).strip(),
            "科类": _track_label(r["track"], prov_id),
            "年份": _num(r["year"]),
            "最低分": _num(r["min_score"]),
            "最低位次": _num(r["min_rank"]) if str(r["min_rank"]).strip() else "",
            "计划数": _num(r["plan"]) if str(r["plan"]).strip() else "",
            "选科要求": str(r["subject_req"]).strip(),
        }
        for _, r in df.iterrows()
    ]
    rows.sort(key=lambda x: (x["年份"], x["科类"], x["院校名称"], -(float(x["最低分"] or 0))))
    out = dist_dir / "app_import" / f"{prov_id}_major.csv"
    _write_csv(rows, MAJOR_COLUMNS, out)
    return out


def build_app_imports(staging_dir: Path = STAGING_DIR, dist_dir: Path = DIST_DIR, prov_id: str = "") -> list[Path]:
    """导出该省 App 可直接导入的三个 CSV（缺哪张表就跳过哪张）。"""
    if not prov_id:
        prov_id = _guess_prov_id(staging_dir)
    out: list[Path] = []
    for fn in (build_rank_export, build_admission_export, build_major_export):
        path = fn(staging_dir, dist_dir, prov_id)
        if path:
            out.append(path)
    return out


def all_prov_ids(staging_dir: Path) -> list[str]:
    """staging 里出现过的所有省份，用于一次导出全部省份的产物。"""
    seen: list[str] = []
    for kind in ("admission", "rank_table", "major_admission", "university_meta"):
        df = _read_staging(kind, staging_dir)
        if df.empty or "prov_id" not in df.columns:
            continue
        for value in df["prov_id"].tolist():
            prov = str(value).strip()
            if prov and prov not in seen:
                seen.append(prov)
    return sorted(seen)


def _guess_prov_id(staging_dir: Path) -> str:
    """从 staging 表里的 prov_id 反推省份，用于默认文件名。"""
    for kind in ("rank_table", "admission", "major_admission", "university_meta"):
        df = _read_staging(kind, staging_dir)
        if not df.empty and "prov_id" in df.columns:
            values = [v for v in df["prov_id"].tolist() if str(v).strip()]
            if values:
                return str(values[0]).strip()
    # 退回 staging 目录同级配置里唯一能匹配上的省份
    for path in sorted(CONFIG_DIR.glob("*.toml")):
        if (staging_dir / f"{path.stem}.csv").exists():
            return path.stem
    return "unknown"


def main() -> None:
    parser = argparse.ArgumentParser(description="生成 App 院校库产物")
    parser.add_argument("--staging", default=str(STAGING_DIR))
    parser.add_argument("--dist", default=str(DIST_DIR))
    parser.add_argument("--builtin", default="", help="App 内置院校 CSV（name,prov,city,level,kind,nature,uni_code）")
    parser.add_argument("--prov", default="", help="省份 id（henan）；省略则按 staging 里的 prov_id 推断")
    parser.add_argument("--only", choices=["universities", "app-import"], default="", help="只生成某一类产物")
    parser.add_argument("--all", action="store_true", help="导出 staging 里全部省份的导入 CSV")
    args = parser.parse_args()

    staging = Path(args.staging)
    dist = Path(args.dist)

    if args.only != "app-import":
        out = build_universities(staging, dist, Path(args.builtin) if args.builtin else None)
        rows = sum(1 for _ in out.open(encoding="utf-8")) - 1
        print(f"已生成 {out}（{rows} 所院校）")

    if args.only != "universities":
        provs = all_prov_ids(staging) if args.all else [args.prov]
        for prov in provs:
            for path in build_app_imports(staging, dist, prov):
                rows = sum(1 for _ in path.open(encoding="utf-8")) - 1
                print(f"已生成 {path}（{rows} 行）")


if __name__ == "__main__":
    main()
