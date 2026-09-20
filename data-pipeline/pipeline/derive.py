"""从投档线派生院校主数据：官方院校代码、所在地、办学性质、层次；以及位次口径校正。"""

from __future__ import annotations

import functools

import pandas as pd

from pipeline.config import list_provinces, load_province_config


@functools.lru_cache(maxsize=1)
def province_id_by_name() -> dict[str, str]:
    """中文省名 -> 省份 id（如 河南 -> henan），用于把院校所在地归一到 App 的 id 体系。"""
    mapping: dict[str, str] = {}
    for prov_id in list_provinces():
        cfg = load_province_config(prov_id)
        name = getattr(cfg, "name", None)
        if name:
            mapping[name] = prov_id
    return mapping


_TRUE = {"1", "true", "True", "是", "Y"}


def _level(row: dict) -> str:
    if str(row.get("is_985", "")) in _TRUE:
        return "985"
    if str(row.get("is_211", "")) in _TRUE:
        return "211"
    if row.get("nature") == "民办":
        return "民办/独立学院"
    return "普通本科"


def derive_university_rows(rows: list[dict]) -> list[dict]:
    """按 (uni_code, uni_name) 去重，产出 university_meta 行。"""
    names = province_id_by_name()
    seen: dict[tuple[str, str], dict] = {}
    for row in rows:
        name = (row.get("uni_name") or "").strip()
        if not name:
            continue
        code = (row.get("uni_code") or "").strip()
        key = (code, name)
        if key in seen:
            continue
        prov_name = (row.get("uni_prov") or "").strip()
        seen[key] = {
            "uni_code": code,
            "uni_name": name,
            "uni_prov": names.get(prov_name, prov_name),
            "nature": (row.get("nature") or "").strip(),
            "level": _level(row),
        }
    return list(seen.values())


def rank_lookup(rank_df: pd.DataFrame) -> dict[tuple, list[tuple[float, float]]]:
    """(省份, 年份, 科类) -> [(分数, 位次) 升序]，供位次插值/比对使用。"""
    out: dict[tuple, list[tuple[float, float]]] = {}
    if rank_df is None or rank_df.empty:
        return out
    for _, row in rank_df.iterrows():
        score, rank = _num(row.get("score")), _num(row.get("rank"))
        if score is None or rank is None:
            continue
        key = (str(row.get("prov_id", "")), str(row.get("year", "")), str(row.get("track", "")))
        out.setdefault(key, []).append((score, rank))
    for pairs in out.values():
        pairs.sort()
    return out


def _num(value) -> float | None:
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    return None if f != f else f


def interpolated_rank(pairs: list[tuple[float, float]], score: float) -> float | None:
    """表内插值；分数落在表覆盖范围之外时返回 None（不比对，避免误判）。"""
    if not pairs:
        return None
    if score > pairs[-1][0] or score < pairs[0][0]:
        return None
    if score == pairs[0][0]:
        return pairs[0][1]
    if score == pairs[-1][0]:
        return pairs[-1][1]
    for (s1, r1), (s2, r2) in zip(pairs, pairs[1:]):
        if s1 <= score <= s2:
            span = s2 - s1
            return min(r1, r2) if span == 0 else r1 + (r2 - r1) * (score - s1) / span
    return pairs[-1][1]


def reconcile_min_rank(
    df: pd.DataFrame, rank_df: pd.DataFrame, tolerance: float = 0.05, refill: bool = True
) -> tuple[pd.DataFrame, dict]:
    """位次口径校正：用一分一段表核对 min_rank，不符的按表重算（refill=False 时改为置空）。

    背景：部分数据源（如 Gaokao-Compass 的 school-admission）的 min_rank 不是「最低分位次」：
    河南 2025 物理类 706 条可比行全部系统性偏小（中位仅期望值的 0.677 倍，北大医学部 674 分标
    82 位，而 82 位对应 702 分），疑似填的是最高分位次。错误位次比没有位次更危险——App 的位次法
    概率会据此把院校判成「几乎不可能」。处理分两步：

    1) 逐行比对：偏差超容差的按一分一段表插值重算（refill=False 时改为置空）；
    2) 某来源可比行里过半不符 → 判定该来源位次口径整体不可用，把该来源**无法逐行比对**的行
       （如河南历史类，缺一分一段表）位次一并置空，避免同源错误数据留在库里。
    """
    stats: dict = {}
    if df is None or df.empty or rank_df is None or rank_df.empty:
        return df, stats
    if "min_rank" not in df.columns:
        return df, stats

    lookup = rank_lookup(rank_df)
    actions: list[str] = []  # empty | uncompared | keep | fix
    values: list = []
    sources: list[str] = []
    had_rank: list[bool] = []
    compared_by_source: dict[str, int] = {}
    bad_by_source: dict[str, int] = {}
    ratios: list[float] = []

    for _, row in df.iterrows():
        src = str(row.get("source", "") or "")
        sources.append(src)
        rank = _num(row.get("min_rank"))
        score = _num(row.get("min_score"))
        pairs = lookup.get((str(row.get("prov_id", "")), str(row.get("year", "")), str(row.get("track", ""))))
        expected = interpolated_rank(pairs, score) if (pairs and score is not None) else None
        had_rank.append(rank is not None)
        if rank is None:
            actions.append("empty")
            values.append("")
            continue
        if not expected:
            actions.append("uncompared")  # 缺一分一段表或分数在表外，二阶段再定
            values.append(rank)
            continue
        compared_by_source[src] = compared_by_source.get(src, 0) + 1
        if abs(rank - expected) / expected > tolerance:
            bad_by_source[src] = bad_by_source.get(src, 0) + 1
            ratios.append(rank / expected)
            actions.append("fix")
            values.append(round(expected) if refill else "")
        else:
            actions.append("keep")
            values.append(rank)

    # 二阶段：口径整体不可用的来源，其无法比对的行位次一律清空
    unreliable = {
        src for src, n in compared_by_source.items() if n >= 5 and bad_by_source.get(src, 0) / n >= 0.5
    }
    if unreliable:
        for i, (act, src) in enumerate(zip(actions, sources)):
            if act == "uncompared" and src in unreliable:
                actions[i] = "empty"
                values[i] = ""

    refilled = sum(1 for a, v in zip(actions, values) if a == "fix" and v != "")
    dropped = sum(
        1 for a, h, v in zip(actions, had_rank, values) if h and (a == "empty" or (a == "fix" and (v == "" or v is None)))
    )
    if not refilled and not dropped:
        return df, stats

    out = df.copy()
    out["min_rank"] = ["" if v is None else v for v in values]
    stats = {"compared": sum(compared_by_source.values())}
    if refilled:
        stats["refilled"] = refilled
        stats["note"] = "min_rank 与一分一段表不符，已按表重算"
    if dropped:
        stats["dropped"] = dropped
        stats["note"] = (stats.get("note", "") + "；无法重算的已置空").lstrip("；")
    if ratios:
        ratios.sort()
        stats["median_ratio"] = round(ratios[len(ratios) // 2], 3)
    if unreliable:
        stats["unreliable_sources"] = sorted(unreliable)
        stats["verdict"] = "该来源 min_rank 口径整体不可用（疑似非最低分位次），已按一分一段表重算/置空"
    return out, stats
