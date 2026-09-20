"""L1 结构校验：阻断级，出错的数据不得进入产物。"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd

from pipeline.contract import TABLES
from pipeline.derive import interpolated_rank
from pipeline.staging import read_table

VALID_TRACKS = {"phy", "his"}
SCORE_MIN, SCORE_MAX = 0, 750
RANK_TOLERANCE = 0.05


@dataclass(frozen=True)
class Issue:
    table: str
    row_index: int
    rule: str
    message: str
    observed: str
    severity: str = "blocking"

    def as_dict(self) -> dict:
        return {
            "table": self.table,
            "row_index": self.row_index,
            "rule": self.rule,
            "message": self.message,
            "observed": self.observed,
            "severity": self.severity,
        }


def has_blocking(issues: list[Issue]) -> bool:
    return any(i.severity == "blocking" for i in issues)


def warnings(issues: list[Issue]) -> list[Issue]:
    return [i for i in issues if i.severity == "warning"]


def _as_float(value) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _check_required(df: pd.DataFrame, kind: str) -> list[Issue]:
    issues: list[Issue] = []
    spec = TABLES[kind]
    for col in spec.required:
        if col not in df.columns:
            continue
        for i, value in df[col].items():
            if value is None or pd.isna(value) or str(value).strip() == "":
                issues.append(Issue(kind, int(i), "required_missing", f"必填列为空: {col}", str(value)))
    for col in ("source", "fetched_at"):
        if col not in df.columns:
            continue
        for i, value in df[col].items():
            if value is None or pd.isna(value) or str(value).strip() == "":
                issues.append(Issue(kind, int(i), "provenance_missing", f"缺少可追溯字段: {col}", str(value)))
    return issues


def _rank_lookup(rank_table: pd.DataFrame) -> dict[tuple, list[tuple[float, float]]]:
    lookup: dict[tuple, list[tuple[float, float]]] = {}
    if rank_table.empty:
        return lookup
    for (prov_id, year, track), group in rank_table.groupby(["prov_id", "year", "track"]):
        pairs = group[["score", "rank"]].apply(pd.to_numeric, errors="coerce").dropna()
        pairs = pairs.sort_values("score").values.tolist()
        lookup[(prov_id, year, track)] = [(float(s), float(r)) for s, r in pairs]
    return lookup


def _check_common(df: pd.DataFrame, kind: str) -> list[Issue]:
    issues: list[Issue] = []
    if df.empty:
        return issues

    if "track" in df.columns:
        for i, value in df["track"].items():
            if value not in VALID_TRACKS:
                issues.append(Issue(kind, int(i), "track_domain", f"track 非法: {value}", str(value)))

    score_col = "min_score" if "min_score" in df.columns else "score"
    if score_col in df.columns:
        for i, value in df[score_col].items():
            if pd.isna(value):
                continue
            score = _as_float(value)
            if score is None:
                issues.append(Issue(kind, int(i), "score_domain", f"{score_col} 非数值: {value}", str(value)))
            elif not (SCORE_MIN <= score <= SCORE_MAX):
                issues.append(Issue(kind, int(i), "score_domain", f"{score_col} 超出 0-750: {value}", str(value)))

    rank_col = "min_rank" if "min_rank" in df.columns else "rank"
    if rank_col in df.columns:
        for i, value in df[rank_col].items():
            if pd.isna(value):
                continue
            rank = _as_float(value)
            if rank is None:
                issues.append(Issue(kind, int(i), "rank_domain", f"{rank_col} 非数值: {value}", str(value)))
            elif rank <= 0:
                issues.append(Issue(kind, int(i), "rank_domain", f"{rank_col} 必须为正: {value}", str(value)))

    key_cols = [c for c in TABLES[kind].unique_key if c in df.columns]
    if key_cols:
        frame = df[key_cols].fillna("")
        dup = frame[frame.duplicated(keep=False)]
        for i in dup.index:
            issues.append(
                Issue(kind, int(i), "unique_key", f"唯一键重复: {key_cols}", str(frame.loc[i].to_dict()))
            )
    return issues


def _check_rank_table(df: pd.DataFrame) -> list[Issue]:
    issues: list[Issue] = []
    if df.empty:
        return issues
    for (_prov, _year, _track), group in df.groupby(["prov_id", "year", "track"]):
        ordered = group.sort_values("score", ascending=False)
        ranks = ordered["rank"].astype(float).tolist()
        for idx, (a, b) in enumerate(zip(ranks, ranks[1:])):
            if b < a:
                row = ordered.iloc[idx + 1]
                issues.append(
                    Issue(
                        "rank_table",
                        int(row.name),
                        "rank_monotonic",
                        f"分数下降但位次变小 @score={row['score']}",
                        f"{a} -> {b}",
                    )
                )
                break
    return issues


def _check_admission(df: pd.DataFrame, rank_lookup: dict) -> list[Issue]:
    issues: list[Issue] = []
    if df.empty or not rank_lookup:
        return issues
    for i, row in df.iterrows():
        score, rank = _as_float(row.get("min_score")), _as_float(row.get("min_rank"))
        if score is None or rank is None:
            continue
        pairs = rank_lookup.get((row["prov_id"], row["year"], row["track"]))
        expected = interpolated_rank(pairs, score) if pairs else None
        if not expected:
            continue
        if abs(rank - expected) / expected > RANK_TOLERANCE:
            issues.append(
                Issue(
                    "admission",
                    int(i),
                    "score_rank_consistency",
                    f"{row['uni_name']} 位次与一分一段表不符 (score={score})",
                    f"observed={rank}, expected≈{round(expected)}",
                    severity="warning",  # 口径分歧需人工判断，不阻断整批
                )
            )
    return issues


def _check_rank_table_coverage(df: pd.DataFrame) -> list[Issue]:
    """一省一年缺任一科类的一分一段表 → 该科类位次只能靠推算，必须提示。"""
    issues: list[Issue] = []
    if df.empty:
        return issues
    for (_prov, year), group in df.groupby(["prov_id", "year"]):
        tracks = set(group["track"].dropna())
        missing = {"phy", "his"} - tracks
        if missing:
            issues.append(
                Issue(
                    "rank_table",
                    0,
                    "track_coverage",
                    f"{year} 年一分一段表缺科类: {sorted(missing)}",
                    f"已有={sorted(tracks)}",
                    severity="warning",
                )
            )
    return issues


def validate_staging(staging_dir: Path) -> list[Issue]:
    issues: list[Issue] = []
    rank_table = read_table("rank_table", staging_dir)
    rank_lookup = _rank_lookup(rank_table)

    for kind in TABLES:
        df = read_table(kind, staging_dir)
        if df.empty:
            continue
        issues += _check_required(df, kind)
        issues += _check_common(df, kind)
        if kind == "rank_table":
            issues += _check_rank_table(df)
            issues += _check_rank_table_coverage(df)
        elif kind == "admission":
            issues += _check_admission(df, rank_lookup)

    return issues
