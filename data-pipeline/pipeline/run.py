"""编排层：配置 → 抓取 → 解析 → 归一 → 落 staging → 校验。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from pipeline.config import SourceSpec, list_provinces, load_province_config
from pipeline.contract import TABLES
from pipeline.derive import aggregate_university_meta, derive_university_rows, reconcile_min_rank
from pipeline.fetch import archive_path, resolve_url
from pipeline.normalize import normalize_rows
from pipeline.parse import parse_source
from pipeline.providers.base import MissingArchive, archive_dest
from pipeline.providers.hf_csv import ensure_local
from pipeline.staging import table_path, write_table
from pipeline.validate import validate_staging
from pipeline.years import resolve_years

STAGING_DIR = Path(__file__).resolve().parent.parent / "staging"
REPORT_PATH = STAGING_DIR / "run_report.json"


def _fetch(spec: SourceSpec, year: int, prov_id: str, force: bool) -> Path:
    """本地人工下载类来源（hf_csv / prov_pdf）只校验副本，其余走抓取层。"""
    url = resolve_url(spec, year)
    dest = archive_dest(spec, year, prov_id)
    if dest is not None:
        return ensure_local(url, dest)
    from pipeline.fetch import fetch_source

    return fetch_source(spec, year, prov_id, force)


# 关键字段缺失的行没有下游价值（一分一段没有分数、投档线没有最低分），落库前丢掉
REQUIRED_VALUES: dict[str, tuple[str, ...]] = {
    "rank_table": ("score", "rank"),
    "admission": ("min_score",),
    "major_admission": ("min_score", "major_name"),
    "batch_lines": ("special", "undergrad"),
}


def _drop_incomplete(df: pd.DataFrame, kind: str) -> tuple[pd.DataFrame, int]:
    """丢掉关键字段为空的行，返回 (清洗后的表, 丢弃行数)。"""
    cols = [c for c in REQUIRED_VALUES.get(kind, ()) if c in df.columns]
    if df.empty or not cols:
        return df, 0
    mask = df[cols[0]].notna() & (df[cols[0]].astype(str).str.strip() != "")
    for col in cols[1:]:
        mask &= df[col].notna() & (df[col].astype(str).str.strip() != "")
    dropped = int((~mask).sum())
    return (df[mask].reset_index(drop=True) if dropped else df), dropped


def _dedupe(df: pd.DataFrame, kind: str) -> tuple[pd.DataFrame, int]:
    """按契约唯一键去重。

    一分一段偶见同一分数两份（如不同批次各一张表），这时保留累计位次更大的那份——
    它统计的是更完整的考生集合，小表只覆盖一段批次，用它做位次换算会系统性偏乐观。
    """
    keys = [c for c in TABLES[kind].unique_key if c in df.columns] if kind in TABLES else []
    if df.empty or not keys:
        return df, 0
    if "rank" in df.columns:
        work = df.assign(_rk=pd.to_numeric(df["rank"], errors="coerce").fillna(-1))
        out = work.sort_values("_rk", ascending=False).drop_duplicates(subset=keys, keep="first")
        out = out.drop(columns=["_rk"])
    elif kind == "university_meta":
        # 同一所院校可能只有部分省份填了城市/层次，保留信息更完整的那条
        work = df.assign(_full=df.notna().sum(axis=1))
        out = work.sort_values("_full", ascending=False).drop_duplicates(subset=keys, keep="first")
        out = out.drop(columns=["_full"])
    else:
        out = df.drop_duplicates(subset=keys, keep="first")
    dropped = len(df) - len(out)
    return (out.sort_index().reset_index(drop=True) if dropped else df), dropped


def _key_text(value) -> str:
    """合并键归一化：CSV 往返后 1244 / 1244.0 / "1244" 要能判为同一所院校。

    缺失值尤其要统一：内存里是 pd.NA（str 得 "<NA>"），落盘读回变成 NaN（"nan"），
    不归一化的话「院校代码缺失」的两条重复行会一直去不掉。
    """
    if value is None or (isinstance(value, float) and value != value):
        return ""
    text = str(value).strip()
    if text.lower() in ("", "nan", "<na>", "none", "nat"):
        return ""
    return text[:-2] if text.endswith(".0") else text


def _merge_existing(
    merged: pd.DataFrame, kind: str, staging_dir: Path, prov_id: str, years: list[int]
) -> pd.DataFrame:
    """多省批跑时 staging 是共享的：只替换本次省份+年份的行，别把其他省的数据冲掉。

    university_meta 没有 prov_id（是院校主数据，一行一校），改为按院校代码合并去重。
    """
    path = table_path(kind, staging_dir)
    if not path.exists():
        return merged
    # 历史 staging 可能含坏字节，容错读：坏字符替换 + 跳过坏行，别让批跑到一半崩掉
    old = pd.read_csv(path, encoding="utf-8", encoding_errors="replace", on_bad_lines="warn")
    if old.empty:
        return merged
    if kind == "university_meta":
        # 同一所大学各省招生代码不同，只能按规范名聚合；否则跨省累积出上万条重复院校
        both = pd.concat([old, merged], ignore_index=True)
        return aggregate_university_meta(both)
    if "prov_id" not in old.columns or "year" not in old.columns:
        return merged
    touched = {str(y) for y in years}
    keep = old[~((old["prov_id"].astype(str) == prov_id) & (old["year"].astype(str).isin(touched)))]
    if merged is None or merged.empty:
        return keep
    return pd.concat([keep, merged], ignore_index=True)


def run_province(
    prov_id: str,
    staging_dir: Path = STAGING_DIR,
    years: list[int] | None = None,
    force: bool = False,
    validate: bool = True,
) -> dict:
    """跑单个省份；多省批量跑时传 validate=False，最后统一校验一次（避免同一批告警重复计数）。"""
    cfg = load_province_config(prov_id)
    years = years or [resolve_years().target_year]
    frames: dict[str, list[pd.DataFrame]] = {}
    report: dict = {
        "prov_id": prov_id,
        "years": years,
        "sources": [],
        "unmatched_universities": 0,
        "blocking_issues": 0,
        "issues": [],
    }

    for year in years:
        for spec in cfg.sources:
            entry = {"kind": spec.kind, "year": year, "parser": spec.parser}
            if spec.disabled:
                entry.update({"status": "disabled", "note": spec.note})
                report["sources"].append(entry)
                continue
            try:
                raw = _fetch(spec, year, prov_id, force)
                rows = parse_source(spec, raw)
            except MissingArchive as exc:  # 需要人工下载，不算失败
                entry.update({"status": "missing", "url": resolve_url(spec, year), "error": str(exc)})
                report["sources"].append(entry)
                continue
            except Exception as exc:  # 单个来源失败不阻断其余来源
                entry.update({"status": "failed", "error": str(exc)})
                report["sources"].append(entry)
                continue

            source_url = resolve_url(spec, year)
            # 单轨来源（如只有历史类的一分一段 PDF）在配置里用 options.track 指定，避免被默认成物理类
            default_track = spec.options.get("track", "phy")
            df = normalize_rows(rows, spec.kind, prov_id, year, default_track, source_url, cfg.mode)
            if "uni_raw" in df.columns and not df.empty:
                report["unmatched_universities"] += int((df["uni_name"] == df["uni_raw"]).sum())
            frames.setdefault(spec.kind, []).append(df)
            if spec.kind == "admission":
                uni_rows = derive_university_rows(rows)
                if uni_rows:
                    frames.setdefault("university_meta", []).append(
                        normalize_rows(
                            uni_rows, "university_meta", prov_id, year, default_track, source_url, cfg.mode
                        )
                    )
            entry.update({"status": "ok", "rows": len(df)})
            report["sources"].append(entry)

    # 位次口径校正要用一分一段表，先单独合并出来（frames 的顺序取决于 sources 顺序）
    rank_df = pd.concat(frames["rank_table"], ignore_index=True) if frames.get("rank_table") else pd.DataFrame()

    for kind, parts in frames.items():
        merged = pd.concat(parts, ignore_index=True) if parts else pd.DataFrame()
        if kind == "university_meta" and not merged.empty:
            merged = merged.drop_duplicates(subset=["uni_code", "uni_name"], keep="first")
        if kind in ("admission", "major_admission") and not merged.empty and not rank_df.empty:
            merged, stats = reconcile_min_rank(merged, rank_df)
            if stats:
                report.setdefault("rank_reconcile", {})[kind] = stats
        merged, invalid = _drop_incomplete(merged, kind)
        if kind == "university_meta":
            merged = aggregate_university_meta(merged)
        merged, dupes = _dedupe(merged, kind)
        if dupes:
            report["dropped_duplicate_rows"] = report.get("dropped_duplicate_rows", 0) + dupes
        if invalid:
            report["dropped_invalid_rows"] = report.get("dropped_invalid_rows", 0) + invalid
        merged = _merge_existing(merged, kind, staging_dir, prov_id, years)
        write_table(merged, kind, staging_dir)
        report[f"{kind}_rows"] = len(merged)

    if validate:
        report.update(validation_summary(staging_dir))
    return report


def validation_summary(staging_dir: Path) -> dict:
    issues = validate_staging(staging_dir)
    blocking = [i.as_dict() for i in issues if i.severity == "blocking"][:50]
    return {
        "blocking_issues": len(blocking),
        "warning_issues": sum(1 for i in issues if i.severity == "warning"),
        "issues": blocking,
    }


def manifest(prov_ids: list[str], years: list[int]) -> list[dict]:
    """列出需要人工下载的来源：URL + 目标本地路径。"""
    items = []
    for prov_id in prov_ids:
        cfg = load_province_config(prov_id)
        for spec in cfg.sources:
            for year in years:
                url = resolve_url(spec, year)
                dest = archive_dest(spec, year, prov_id)
                items.append(
                    {
                        "prov_id": prov_id,
                        "kind": spec.kind,
                        "year": year,
                        "url": url,
                        "dest": str(dest) if dest else str(archive_path(url, spec.kind, year, prov_id)),
                    }
                )
    return items


def main() -> None:
    parser = argparse.ArgumentParser(description="抓取并归一化官方高考数据")
    parser.add_argument("--prov", help="省份 id，如 henan；或用 --all 跑全部")
    parser.add_argument("--year", type=int, action="append", help="年份，可重复")
    parser.add_argument("--all", action="store_true", help="跑 configs/provinces 下所有省份")
    parser.add_argument("--staging", default=str(STAGING_DIR))
    parser.add_argument("--force", action="store_true", help="忽略 raw 缓存重新下载")
    parser.add_argument("--list", action="store_true", help="只打印需人工下载的清单，不跑流程")
    args = parser.parse_args()

    if not args.all and not args.prov:
        parser.error("需要 --prov <省份id> 或 --all")
    provs = list_provinces() if args.all else [args.prov]
    years = args.year or [resolve_years().target_year]

    if args.list:
        for item in manifest(provs, years):
            print(f"{item['url']}\n  -> {item['dest']}")
        return
    staging = Path(args.staging)
    staging.mkdir(parents=True, exist_ok=True)
    reports = [run_province(p, staging, years, args.force, validate=False) for p in provs]
    summary = validation_summary(staging)  # staging 是共享的，跑完全部省份只校验一次
    payload = {"years": years, "provinces": reports, **summary}
    (staging / "run_report.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    for r in reports:
        stats: dict[str, list[str]] = {}
        for source in r["sources"]:
            # 同一 kind 可能有多个来源（如物理类走数据集、历史类走 PDF），状态要逐个列出
            stats.setdefault(source["kind"], []).append(f"{source['parser']}={source.get('status')}")
        detail = " ".join(f"{k}[{','.join(v)}]" for k, v in stats.items())
        print(f"{r['prov_id']}: {detail}")
    print(f"阻断问题={summary['blocking_issues']} 警告={summary['warning_issues']}")


if __name__ == "__main__":
    main()
