"""多省批跑相关：staging 按省合并（不能互相覆盖）、源数据坏字符清洗。"""

from __future__ import annotations

import pandas as pd

from pipeline.derive import aggregate_university_meta
from pipeline.providers.base import apply_column_map, clean_text
from pipeline.run import _dedupe, _drop_incomplete, _key_text, _merge_existing


def test_merge_existing_replaces_only_this_province(tmp_path):
    """批跑时 staging 是共享的：写广东不能把河南的数据冲掉，但要替换掉广东自己的旧行。"""
    old = pd.DataFrame(
        {
            "prov_id": ["henan", "guangdong"],
            "year": ["2025", "2025"],
            "track": ["phy", "phy"],
            "score": ["600", "610"],
            "rank": ["10000", "9000"],
        }
    )
    old.to_csv(tmp_path / "rank_table.csv", index=False)
    new = pd.DataFrame(
        {"prov_id": ["guangdong"], "year": ["2025"], "track": ["phy"], "score": ["611"], "rank": ["8900"]}
    )
    out = _merge_existing(new, "rank_table", tmp_path, "guangdong", [2025])
    got = set(zip(out["prov_id"], out["score"].astype(str)))
    assert got == {("henan", "600"), ("guangdong", "611")}


def test_merge_existing_keeps_other_years(tmp_path):
    old = pd.DataFrame({"prov_id": ["henan", "henan"], "year": ["2024", "2025"], "score": ["600", "605"]})
    old.to_csv(tmp_path / "admission.csv", index=False)
    new = pd.DataFrame({"prov_id": ["henan"], "year": ["2025"], "score": ["610"]})
    out = _merge_existing(new, "admission", tmp_path, "henan", [2025])
    assert sorted(out["year"].astype(str)) == ["2024", "2025"]
    assert sorted(out["score"].astype(str)) == ["600", "610"]


def test_merge_existing_without_file_returns_new(tmp_path):
    new = pd.DataFrame({"prov_id": ["henan"], "year": ["2025"], "score": ["600"]})
    out = _merge_existing(new, "admission", tmp_path, "henan", [2025])
    assert len(out) == 1


def test_merge_university_meta_dedupes_by_school(tmp_path):
    """院校主数据没有省份归属概念，按院校合并去重，后跑的省补充新院校。"""
    old = pd.DataFrame({"uni_code": ["1", "2"], "uni_name": ["甲大学", "乙大学"], "city": ["", "广州"]})
    old.to_csv(tmp_path / "university_meta.csv", index=False)
    new = pd.DataFrame({"uni_code": ["2", "3"], "uni_name": ["乙大学", "丙大学"], "city": ["深圳", "成都"]})
    out = _merge_existing(new, "university_meta", tmp_path, "guangdong", [2025])
    assert list(out["uni_name"]) == ["甲大学", "乙大学", "丙大学"]
    assert out.loc[out["uni_name"] == "乙大学", "city"].iloc[0] == "深圳"  # 新数据覆盖旧数据


def test_clean_text_removes_broken_utf8_marks():
    """数据集里有截断的 UTF-8 字节，清洗后不能把 staging CSV 写歪。"""
    assert clean_text("天津医\ufffd科大学") == "天津医科大学"
    assert clean_text(" 甲大学\u3000 ") == "甲大学"
    assert clean_text("甲\x00乙\x0b丙") == "甲乙丙"


def test_apply_column_map_cleans_values():
    headers = ["院校名称", "最低分"]
    body = [["天津医\ufffd科大学", "600"]]
    rows, dropped = apply_column_map(headers, body, {"院校名称": "uni_name", "最低分": "min_score"}, [])
    assert dropped == 0
    assert rows[0]["uni_name"] == "天津医科大学"


def test_key_text_normalizes_missing_and_numeric():
    """院校代码缺失时内存里是 pd.NA、落盘读回是 NaN，两者必须判为同一个键。"""
    assert _key_text(pd.NA) == ""
    assert _key_text(float("nan")) == ""
    assert _key_text(None) == ""
    assert _key_text("1244.0") == "1244"
    assert _key_text("1244") == "1244"


def test_merge_university_meta_dedupes_when_code_missing(tmp_path):
    """院校代码缺失时按院校名去重：不同省份投档线会各贡献一条同名院校。"""
    old = pd.DataFrame({"uni_code": [pd.NA], "uni_name": ["重庆医科大学莱斯特大学联合学院"], "city": [pd.NA]})
    old.to_csv(tmp_path / "university_meta.csv", index=False)
    new = pd.DataFrame({"uni_code": [pd.NA], "uni_name": ["重庆医科大学莱斯特大学联合学院"], "city": ["重庆"]})
    out = _merge_existing(new, "university_meta", tmp_path, "zhejiang", [2025])
    assert len(out) == 1
    assert out["city"].iloc[0] == "重庆"


def test_drop_incomplete_and_dedupe():
    import pandas as pd

    rt = pd.DataFrame(
        {
            "prov_id": ["henan", "henan", "henan"],
            "year": ["2025"] * 3,
            "track": ["phy"] * 3,
            "score": ["600", "", "600"],
            "rank": ["10000", "500", "12000"],
        }
    )
    kept, dropped = _drop_incomplete(rt, "rank_table")
    assert dropped == 1 and len(kept) == 2
    # 同一分数两份表（不同批次口径）时保留累计人数更大的那份
    deduped, dupes = _dedupe(kept, "rank_table")
    assert dupes == 1 and deduped["rank"].iloc[0] == "12000"


def test_aggregate_university_meta_merges_school_codes():
    """同一所大学在各省招生代码不同，聚合后应只剩一条。"""
    df = pd.DataFrame(
        {
            "uni_code": ["1008", "2311", "4412"],
            "uni_name": ["山东大学", "山东大学", "山东大学（威海）"],
            "uni_prov": ["shandong", "shandong", "shandong"],
            "city": ["济南", "济南", "威海"],
            "level": ["985/211", "985/211", "985/211"],
            "kind": ["综合类", "", "综合类"],
            "nature": ["公办", "公办", "公办"],
            "source": ["a", "b", "c"],
            "fetched_at": ["t"] * 3,
        }
    )
    out = aggregate_university_meta(df)
    # 山东大学（威海）是另一个校区（另一个招生单位），不能并进山东大学
    assert len(out) == 2
    row = out[out["uni_name"] == "山东大学"].iloc[0]
    assert row["uni_code"] in ("1008", "2311")  # 两个代码各出现一次，取其一
    assert row["kind"] == "综合类"  # 空值不参与众数
    assert out[out["uni_name"] == "山东大学（威海）"].iloc[0]["city"] == "威海"


def test_build_exports_filter_by_province(tmp_path):
    """全量批跑后 staging 是共享的：每省产物只能含本省数据。"""
    from pipeline.build import build_rank_export

    staging = tmp_path / "staging"
    staging.mkdir()
    pd.DataFrame(
        {
            "prov_id": ["henan", "henan", "guangdong"],
            "year": ["2025"] * 3,
            "track": ["phy", "his", "phy"],
            "score": ["600", "600", "600"],
            "rank": ["10000", "3000", "9000"],
        }
    ).to_csv(staging / "rank_table.csv", index=False)
    out = build_rank_export(staging, tmp_path / "dist", "henan")
    text = out.read_text(encoding="utf-8")
    assert text.count("河南") == 2
    assert "广东" not in text


def test_build_universities_province_written_in_chinese(tmp_path):
    """院校属地列必须是中文名：App 侧按名称匹配省份，拼音 id 会匹配不上。"""
    from pipeline.build import build_universities

    staging = tmp_path / "staging"
    staging.mkdir()
    pd.DataFrame(
        {
            "uni_code": ["1"],
            "uni_name": ["甲大学"],
            "uni_prov": ["heilongjiang"],
            "level": ["普通本科"],
            "kind": [""],
            "nature": ["公办"],
            "city": [""],
            "source": ["test"],
            "fetched_at": ["2026-09-20"],
        }
    ).to_csv(staging / "university_meta.csv", index=False)
    out = build_universities(staging, tmp_path / "dist")
    row = pd.read_csv(out, dtype=str).iloc[0]
    assert row["prov"] == "黑龙江"


def test_admission_export_keeps_batch(tmp_path):
    """投档线导出必须保留批次，且不能跨批次合并（专科线不能被当成院校线）。"""
    from pipeline.build import build_admission_export

    staging = tmp_path / "staging"
    staging.mkdir()
    pd.DataFrame(
        {
            "prov_id": ["x"] * 3,
            "year": ["2025"] * 3,
            "track": ["phy"] * 3,
            "batch": ["本科批", "专科批", "本科批"],
            "group": ["（001）", "（002）", "（003）"],
            "uni_name": ["甲大学"] * 3,
            "uni_raw": ["甲大学"] * 3,
            "min_score": [500.0, 392.0, 505.0],
            "min_rank": [10000.0, 90000.0, 9000.0],
            "plan": [1, 2, 3],
            "source": ["test"] * 3,
            "fetched_at": ["2026-09-20"] * 3,
        }
    ).to_csv(staging / "admission.csv", index=False)
    out = build_admission_export(staging, tmp_path / "dist", "x")
    df = pd.read_csv(out, dtype=str)
    assert set(df["批次"]) == {"本科批", "专科批"}
    ug = df[df["批次"] == "本科批"].iloc[0]
    assert float(ug["最低分"]) == 500.0
