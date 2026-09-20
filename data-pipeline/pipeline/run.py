"""编排层：配置 → 抓取 → 解析 → 归一 → 落 staging → 校验。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from pipeline.config import SourceSpec, list_provinces, load_province_config
from pipeline.derive import derive_university_rows, reconcile_min_rank
from pipeline.fetch import archive_path, resolve_url
from pipeline.normalize import normalize_rows
from pipeline.parse import parse_source
from pipeline.providers.base import MissingArchive, archive_dest
from pipeline.providers.hf_csv import ensure_local
from pipeline.staging import write_table
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
