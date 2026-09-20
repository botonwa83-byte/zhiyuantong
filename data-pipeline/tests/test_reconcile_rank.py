"""位次口径校正：min_rank 与一分一段表不符时按表重算，无法重算的置空。"""

from __future__ import annotations

import pandas as pd

from pipeline.derive import interpolated_rank, rank_lookup, reconcile_min_rank


def _rank() -> pd.DataFrame:
    # 600 分 → 1 万位，610 分 → 9 千位（分数越高位次越小）
    return pd.DataFrame(
        [
            {"prov_id": "henan", "year": "2025", "track": "phy", "score": "600", "rank": "10000"},
            {"prov_id": "henan", "year": "2025", "track": "phy", "score": "610", "rank": "9000"},
        ]
    )


def _rows(scores: list[str], ranks: list[str], sources: list[str], tracks: list[str] | None = None) -> pd.DataFrame:
    """造 admission 表；source 决定「整源不可用」的判定范围（阈值要求至少 5 条可比行）。"""
    return pd.DataFrame(
        {
            "prov_id": ["henan"] * len(ranks),
            "year": ["2025"] * len(ranks),
            "track": tracks or ["phy"] * len(ranks),
            "uni_name": [f"院校{i}" for i in range(len(ranks))],
            "min_score": scores,
            "min_rank": ranks,
            "source": sources,
        }
    )


def _as_float(series: pd.Series) -> list[float]:
    return [float(v) if str(v).strip() else 0.0 for v in series]


def test_interpolated_rank_and_lookup():
    pairs = rank_lookup(_rank())[("henan", "2025", "phy")]
    assert pairs == [(600.0, 10000.0), (610.0, 9000.0)]
    assert interpolated_rank(pairs, 605) == 9500
    assert interpolated_rank(pairs, 599) is None  # 表覆盖范围外不比对


def test_consistent_rank_is_kept():
    df = _rows(["605"], ["9500"], ["src-a"])
    out, stats = reconcile_min_rank(df, _rank())
    assert _as_float(out["min_rank"]) == [9500.0]
    assert stats == {}  # 没有需要修正的


def test_inconsistent_rank_is_refilled():
    """674 分标 82 位（真实约 1917 位）这类偏差 → 按一分一段表重算。"""
    scores = ["600", "602", "604", "606", "608", "610"]
    df = _rows(scores, ["82", "961", "500", "700", "900", "1000"], ["src-a"] * 6)
    out, stats = reconcile_min_rank(df, _rank())
    assert _as_float(out["min_rank"]) == [10000.0, 9800.0, 9600.0, 9400.0, 9200.0, 9000.0]
    assert stats["refilled"] == 6 and stats["compared"] == 6
    assert stats["median_ratio"] < 0.2
    assert stats["unreliable_sources"] == ["src-a"]


def test_refill_can_be_disabled():
    """refill=False 时改为置空（宁缺勿错，适合下游不接受估算位次的场景）。"""
    scores = ["600", "602", "604", "606", "608", "610"]
    df = _rows(scores, ["82", "961", "500", "700", "900", "1000"], ["src-a"] * 6)
    out, stats = reconcile_min_rank(df, _rank(), refill=False)
    assert _as_float(out["min_rank"]) == [0.0] * 6
    assert stats["dropped"] == 6 and "refilled" not in stats


def test_unreliable_source_drops_uncomparable_rows():
    """同一来源过半不符 → 该来源无法逐行比对的行（如缺一分一段表的历史类）位次清空。"""
    df = _rows(
        ["600", "602", "604", "606", "608", "610", "590"],
        ["82", "961", "500", "700", "900", "1000", "5000"],
        ["src-a"] * 7,
        tracks=["phy"] * 6 + ["his"],  # 历史类没有一分一段表，无法逐行比对
    )
    out, stats = reconcile_min_rank(df, _rank())
    assert _as_float(out["min_rank"]) == [10000.0, 9800.0, 9600.0, 9400.0, 9200.0, 9000.0, 0.0]
    assert stats["compared"] == 6 and stats["refilled"] == 6 and stats["dropped"] == 1


def test_other_source_is_untouched():
    """口径正常的来源不受牵连。"""
    scores = ["600", "602", "604", "606", "608", "610"]
    good = ["10000", "9800", "9600", "9400", "9200", "9000"]
    df = pd.concat(
        [
            _rows(scores, ["82"] * 6, ["src-a"] * 6),
            _rows(scores, good, ["src-b"] * 6),
        ],
        ignore_index=True,
    )
    out, stats = reconcile_min_rank(df, _rank())
    assert _as_float(out["min_rank"]) == [10000.0, 9800.0, 9600.0, 9400.0, 9200.0, 9000.0] + [float(g) for g in good]
    assert stats["unreliable_sources"] == ["src-a"] and stats["refilled"] == 6


def test_no_rank_table_means_no_change():
    df = _rows(["605"], ["82"], ["src-a"])
    out, stats = reconcile_min_rank(df, pd.DataFrame())
    assert _as_float(out["min_rank"]) == [82.0] and stats == {}
