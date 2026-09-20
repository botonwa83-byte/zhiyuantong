import pandas as pd

from pipeline.contract import TABLES
from pipeline.staging import read_table, write_table


def test_roundtrip_preserves_columns(tmp_path):
    df = pd.DataFrame(
        [{"prov_id": "henan", "year": 2025, "track": "phy", "score": 600, "rank": 1000, "cum_count": 120}]
    )
    write_table(df, "rank_table", tmp_path)
    out = read_table("rank_table", tmp_path)
    assert list(out.columns) == list(TABLES["rank_table"].columns)
    assert len(out) == 1


def test_missing_required_column_rejected(tmp_path):
    df = pd.DataFrame([{"prov_id": "henan", "score": 600}])
    try:
        write_table(df, "rank_table", tmp_path)
    except ValueError as e:
        assert "缺少必需列" in str(e)
        assert "track" in str(e)
    else:
        raise AssertionError("应拒绝缺列")


def test_unknown_kind_rejected(tmp_path):
    try:
        write_table(pd.DataFrame(), "nope", tmp_path)
    except KeyError:
        pass
    else:
        raise AssertionError("未知表类型应报错")


def test_read_missing_table_returns_empty(tmp_path):
    out = read_table("plan", tmp_path)
    assert list(out.columns) == list(TABLES["plan"].columns)
    assert out.empty
