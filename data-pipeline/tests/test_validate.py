import pandas as pd

from pipeline.staging import read_table, write_table
from pipeline.validate import has_blocking, validate_staging

PROVENANCE = {"source": "https://example.org/2025", "fetched_at": "2026-09-18T00:00:00+00:00"}


def _rank_df(rows):
    return pd.DataFrame(
        [{"prov_id": "henan", "year": 2025, "track": "phy", "score": s, "rank": r, **PROVENANCE}
         for s, r in rows]
    )


def _admission(min_score, min_rank):
    return pd.DataFrame([{
        "prov_id": "henan", "year": 2025, "track": "phy", "batch": "本科批",
        "uni_name": "郑州大学", "uni_raw": "郑州大学", "min_score": min_score,
        "min_rank": min_rank, **PROVENANCE,
    }])


def test_detects_rank_not_monotonic(tmp_path):
    # 分数更高却位次更大（更靠后），违反单调性
    write_table(_rank_df([(601, 900), (600, 500)]), "rank_table", tmp_path)
    issues = validate_staging(tmp_path)
    assert has_blocking(issues)
    assert any(i.rule == "rank_monotonic" for i in issues)


def test_clean_tables_pass(tmp_path):
    write_table(_rank_df([(601, 900), (600, 1000)]), "rank_table", tmp_path)
    assert len(read_table("rank_table", tmp_path)) == 2, "表必须真的被读到，避免空表蒙对"
    assert not has_blocking(validate_staging(tmp_path))


def test_detects_score_out_of_domain(tmp_path):
    write_table(_rank_df([(900, 10), (600, 1000)]), "rank_table", tmp_path)
    assert any(i.rule == "score_domain" for i in validate_staging(tmp_path))


def test_detects_non_numeric_score(tmp_path):
    df = pd.DataFrame([{
        "prov_id": "henan", "year": 2025, "track": "phy", "score": "600分", "rank": 1000, **PROVENANCE
    }])
    write_table(df, "rank_table", tmp_path)
    assert any(i.rule == "score_domain" for i in validate_staging(tmp_path))


def test_detects_bad_track(tmp_path):
    df = _rank_df([(600, 1000)])
    df["track"] = "文科"
    write_table(df, "rank_table", tmp_path)
    assert any(i.rule == "track_domain" for i in validate_staging(tmp_path))


def test_detects_duplicate_unique_key(tmp_path):
    write_table(_rank_df([(600, 1000), (600, 1200)]), "rank_table", tmp_path)
    assert any(i.rule == "unique_key" for i in validate_staging(tmp_path))


def test_detects_missing_provenance(tmp_path):
    df = _rank_df([(600, 1000)])
    df["source"] = ""
    write_table(df, "rank_table", tmp_path)
    assert any(i.rule == "provenance_missing" for i in validate_staging(tmp_path))


def test_detects_missing_required_value(tmp_path):
    df = _rank_df([(600, 1000)])
    df.loc[0, "rank"] = None
    write_table(df, "rank_table", tmp_path)
    assert any(i.rule == "required_missing" for i in validate_staging(tmp_path))


def test_admission_rank_must_match_rank_table(tmp_path):
    write_table(_rank_df([(700, 50), (600, 1000), (500, 5000)]), "rank_table", tmp_path)
    write_table(_admission(600, 90000), "admission", tmp_path)
    assert any(i.rule == "score_rank_consistency" for i in validate_staging(tmp_path))


def test_consistent_admission_passes(tmp_path):
    write_table(_rank_df([(700, 50), (600, 1000), (500, 5000)]), "rank_table", tmp_path)
    write_table(_admission(600, 1010), "admission", tmp_path)
    assert len(read_table("admission", tmp_path)) == 1
    assert not has_blocking(validate_staging(tmp_path))


def test_same_university_different_batch_is_not_duplicate(tmp_path):
    write_table(_rank_df([(700, 50), (600, 1000)]), "rank_table", tmp_path)
    df = pd.concat([_admission(600, 1000), _admission(400, 20000)], ignore_index=True)
    df.loc[1, "batch"] = "专科批"
    df.loc[1, "min_score"] = 400
    write_table(df, "admission", tmp_path)
    assert not any(i.rule == "unique_key" for i in validate_staging(tmp_path))
