from pathlib import Path

import pandas as pd
import pytest

from pipeline.config import SourceSpec
from pipeline.parse import parse_source

FIXTURE = Path(__file__).parent / "fixtures" / "sample_table.html"


def test_parse_html_table():
    spec = SourceSpec("rank_table", "x", "html_table", {"columns": ["score", "rank"]})
    rows = parse_source(spec, FIXTURE)
    assert rows[0]["score"] == "700"
    assert rows[0]["rank"] == "58"


def test_parse_html_table_with_column_map():
    spec = SourceSpec("admission", "x", "html_table", {"column_map": {"分数": "score", "位次": "rank"}})
    rows = parse_source(spec, FIXTURE)
    assert rows[1]["score"] == "690"
    assert rows[1]["rank"] == "150"


def test_unknown_parser_raises():
    spec = SourceSpec("rank_table", "x", "nope")
    with pytest.raises(KeyError, match="未知解析器"):
        parse_source(spec, FIXTURE)


def test_zero_rows_raises_instead_of_silently_passing():
    spec = SourceSpec("rank_table", "x", "html_table", {"columns": ["不存在的列"]})
    with pytest.raises(ValueError, match="0 行"):
        parse_source(spec, FIXTURE)


def test_table_index_selects_second_table(tmp_path):
    html = (
        "<table><tr><th>无关</th></tr><tr><td>x</td></tr></table>"
        "<table><tr><th>分数</th><th>位次</th></tr><tr><td>700</td><td>58</td></tr></table>"
    )
    path = tmp_path / "two.html"
    path.write_text(html, encoding="utf-8")
    spec = SourceSpec("rank_table", "x", "html_table", {"columns": ["score", "rank"], "table_index": 1})
    rows = parse_source(spec, path)
    assert rows[0]["score"] == "700"


def test_parse_xls(tmp_path):
    src = tmp_path / "投档线.xlsx"
    pd.DataFrame(
        [{"院校名称": "郑州大学", "最低分": 590, "最低位次": 23000},
         {"院校名称": "河南科技大学", "最低分": 512, "最低位次": 128000}]
    ).to_excel(src, index=False)
    spec = SourceSpec("admission", "x", "xls", {"columns": ["uni", "score", "rank"]})
    rows = parse_source(spec, src)
    assert rows[0]["uni"] == "郑州大学"
    assert rows[0]["score"] == "590"


def test_parse_manual_csv(tmp_path):
    src = tmp_path / "manual.csv"
    src.write_text("uni_name,min_score,min_rank\n郑州大学,590,23000\n", encoding="utf-8")
    spec = SourceSpec("admission", "x", "manual")
    rows = parse_source(spec, src)
    assert rows[0]["uni_name"] == "郑州大学"
    assert rows[0]["min_score"] == "590"
