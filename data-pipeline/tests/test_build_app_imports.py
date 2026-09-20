"""build.py 的 App 可导入产物：表头、聚合口径、省份中文名。"""

from __future__ import annotations

import csv

import pandas as pd

from pipeline.build import (
    ADMISSION_COLUMNS,
    MAJOR_COLUMNS,
    RANK_COLUMNS,
    build_admission_export,
    build_app_imports,
    build_major_export,
    build_rank_export,
)
from pipeline.contract import TABLES


def _df(kind: str, rows: list[dict]) -> pd.DataFrame:
    return pd.DataFrame(rows).reindex(columns=list(TABLES[kind].columns)).fillna("")


def _read(path) -> list[dict]:
    with path.open(encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def test_rank_export_columns_and_province_name(tmp_path):
    df = _df("rank_table", [{"prov_id": "henan", "year": "2025", "track": "物理类", "score": "600", "rank": "20000"}])
    (tmp_path / "staging").mkdir()
    df.to_csv(tmp_path / "staging" / "rank_table.csv", index=False)

    out = build_rank_export(tmp_path / "staging", tmp_path / "dist", "henan")
    assert out is not None and out.exists()
    rows = _read(out)
    assert list(rows[0].keys()) == RANK_COLUMNS
    assert rows[0]["省份"] == "河南"
    assert rows[0]["分数"] == "600" and rows[0]["位次"] == "20000"


def test_admission_export_takes_lowest_group_and_sums_plan(tmp_path):
    df = _df(
        "admission",
        [
            {"prov_id": "henan", "year": "2025", "track": "物理类", "uni_name": "郑州大学", "group": "101", "min_score": "590", "min_rank": "23000", "plan": "100"},
            {"prov_id": "henan", "year": "2025", "track": "物理类", "uni_name": "郑州大学", "group": "102", "min_score": "575", "min_rank": "31000", "plan": "200"},
        ],
    )
    (tmp_path / "staging").mkdir()
    df.to_csv(tmp_path / "staging" / "admission.csv", index=False)

    rows = _read(build_admission_export(tmp_path / "staging", tmp_path / "dist", "henan"))
    assert list(rows[0].keys()) == ADMISSION_COLUMNS
    assert len(rows) == 1  # 同一院校多个专业组聚合为一条院校线
    assert rows[0]["最低分"] == "575"  # 取最低的专业组线
    assert rows[0]["最低位次"] == "31000"
    assert rows[0]["招生计划"] == "300"  # 计划数求和


def test_major_export_keeps_subject_req(tmp_path):
    df = _df(
        "major_admission",
        [
            {"prov_id": "henan", "year": "2025", "track": "物理类", "uni_name": "郑州大学", "major_name": "计算机科学与技术", "min_score": "612", "min_rank": "21000", "plan": "120", "subject_req": "物理+化学"},
        ],
    )
    (tmp_path / "staging").mkdir()
    df.to_csv(tmp_path / "staging" / "major_admission.csv", index=False)

    rows = _read(build_major_export(tmp_path / "staging", tmp_path / "dist", "henan"))
    assert list(rows[0].keys()) == MAJOR_COLUMNS
    assert rows[0]["选科要求"] == "物理+化学"
    assert rows[0]["专业名称"] == "计算机科学与技术"


def test_build_app_imports_skips_missing_tables(tmp_path):
    """只导入了专业录取线时，产物里只出现 major 文件。"""
    staging = tmp_path / "staging"
    staging.mkdir()
    _df("major_admission", [{"prov_id": "henan", "year": "2025", "track": "物理类", "uni_name": "郑州大学", "major_name": "临床医学", "min_score": "631"}]).to_csv(
        staging / "major_admission.csv", index=False
    )

    outs = build_app_imports(staging, tmp_path / "dist")
    assert [p.name for p in outs] == ["henan_major.csv"]
