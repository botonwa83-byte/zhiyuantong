import pandas as pd

from pipeline.aliases import canonical_name
from pipeline.contract import TABLES
from pipeline.normalize import normalize_rows, normalize_track


def test_alias_matches_official_name():
    assert canonical_name("郑州大学(郑州)") == "郑州大学"


def test_fullwidth_and_spaces_are_tolerated():
    assert canonical_name(" 郑州大学 ") == "郑州大学"


def test_unknown_name_returns_none():
    assert canonical_name("某某不存在的大学") is None


def test_normalize_rows_fills_context():
    rows = [{"院校名称": "郑州大学", "最低分": "590", "最低位次": "23,000"}]
    df = normalize_rows(rows, "admission", "henan", 2025, "phy", "https://x")
    assert df.loc[0, "uni_name"] == "郑州大学"
    assert df.loc[0, "min_score"] == 590
    assert df.loc[0, "min_rank"] == 23000
    assert df.loc[0, "track"] == "phy"
    assert df.loc[0, "prov_id"] == "henan"
    assert df.loc[0, "source"] == "https://x"
    assert df.loc[0, "fetched_at"]


def test_track_is_normalized():
    rows = [{"院校名称": "郑州大学", "最低分": "590", "track": "物理类"}]
    df = normalize_rows(rows, "admission", "henan", 2025, "phy", "https://x")
    assert df.loc[0, "track"] == "phy"


def test_combined_track_maps_to_phy_only_in_3plus3():
    assert normalize_track("综合", "phy", mode="3+3") == "phy"


def test_wenke_combined_is_not_mistaken_for_phy():
    # 3+1+2 省份的「文科综合」不能被判成物理类
    assert normalize_track("文科综合", "his", mode="3+1+2") == "his"


def test_unmatched_university_falls_back_to_cleaned_name():
    rows = [{"院校名称": "某某不存在的大学", "最低分": "590"}]
    df = normalize_rows(rows, "admission", "henan", 2025, "phy", "https://x")
    assert df.loc[0, "uni_name"] == "某某不存在的大学"
    assert df.loc[0, "uni_raw"] == "某某不存在的大学"


def test_empty_rows_returns_contract_shaped_frame():
    df = normalize_rows([], "admission", "henan", 2025, "phy", "https://x")
    assert isinstance(df, pd.DataFrame) and df.empty
    assert list(df.columns) == list(TABLES["admission"].columns)


def test_non_numeric_score_becomes_na():
    rows = [{"院校名称": "郑州大学", "最低分": "600分"}]
    df = normalize_rows(rows, "admission", "henan", 2025, "phy", "https://x")
    assert pd.isna(df.loc[0, "min_score"])
