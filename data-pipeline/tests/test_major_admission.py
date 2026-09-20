"""专业级录取数据（major_admission）：人工整理 CSV → 归一 → 落 staging → 校验。"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from pipeline.config import SourceSpec
from pipeline.contract import TABLES
from pipeline.normalize import normalize_rows
from pipeline.providers.base import archive_dest
from pipeline.providers.manual import parse_manual
from pipeline.staging import read_table, write_table
from pipeline.validate import validate_staging

FIXTURE = Path(__file__).parent / "fixtures" / "major_admission.csv"


def test_manual_parser_is_local_only():
    """人工整理来源不联网：缺失本地副本时报 MissingArchive，而不是去下载。"""
    spec = SourceSpec(
        kind="major_admission",
        url_template="https://www.haeea.cn/",
        parser="manual",
        options={"dataset": "major"},
    )
    dest = archive_dest(spec, 2025, "henan")
    assert dest is not None
    assert dest.name == "major_admission_major.csv"
    assert dest.parent.parts[-3:] == ("raw", "henan", "2025")


def test_normalize_major_admission():
    rows, dropped = parse_manual(FIXTURE, {})
    assert dropped == 0
    df = normalize_rows(rows, "major_admission", "henan", 2025, "phy", "manual://test", "3+1+2")

    assert list(df.columns) == list(TABLES["major_admission"].columns)
    assert len(df) == 3
    first = df.iloc[0]
    assert first["uni_name"] == "示例大学A"
    assert first["major_name"] == "计算机科学与技术"
    assert first["min_score"] == 612
    assert first["min_rank"] == 21000
    assert first["plan"] == 120
    assert first["subject_req"] == "物理+化学"
    assert first["track"] == "phy"
    # 第二行是历史类，不能被默认轨覆盖
    assert df.iloc[2]["track"] == "his"


def test_write_and_validate(tmp_path: Path):
    rows, _ = parse_manual(FIXTURE, {})
    df = normalize_rows(rows, "major_admission", "henan", 2025, "phy", "manual://test", "3+1+2")
    write_table(df, "major_admission", tmp_path)

    back = read_table("major_admission", tmp_path)
    assert len(back) == 3
    # 同一「省份+年份+科类+院校+专业」重复落库会被校验判为阻断
    blocking = [i for i in validate_staging(tmp_path) if i.severity == "blocking"]
    assert not blocking, [i.as_dict() for i in blocking]

    # 同一「省份+年份+科类+院校+专业」出现两行 → 阻断
    write_table(pd.concat([df, df], ignore_index=True), "major_admission", tmp_path)
    blocking = [i for i in validate_staging(tmp_path) if i.severity == "blocking"]
    assert any(i.as_dict()["table"] == "major_admission" for i in blocking)
