"""六张标准表的列契约。所有省份适配器的输出都归一到这里。"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class TableSpec:
    name: str
    columns: tuple[str, ...]
    required: tuple[str, ...]
    unique_key: tuple[str, ...]


TABLES: dict[str, TableSpec] = {
    "rank_table": TableSpec(
        "rank_table",
        ("prov_id", "year", "track", "score", "rank", "cum_count", "source", "fetched_at"),
        ("prov_id", "year", "track", "score", "rank"),
        ("prov_id", "year", "track", "score"),
    ),
    "batch_lines": TableSpec(
        "batch_lines",
        (
            "prov_id",
            "year",
            "track",
            "special",
            "undergrad",
            "college",
            "candidates",
            "ug_plan",
            "source",
            "fetched_at",
        ),
        ("prov_id", "year", "track", "special", "undergrad", "college"),
        ("prov_id", "year", "track"),
    ),
    "admission": TableSpec(
        "admission",
        (
            "prov_id",
            "year",
            "track",
            "batch",
            "group",
            "uni_name",
            "uni_raw",
            "min_score",
            "min_rank",
            "plan",
            "source",
            "fetched_at",
        ),
        ("prov_id", "year", "track", "uni_name", "min_score"),
        # 新高考「院校专业组」模式下，一所学校在同一批次有多个专业组各自划线
        ("prov_id", "year", "track", "batch", "uni_name", "group"),
    ),
    "major_admission": TableSpec(
        "major_admission",
        (
            "prov_id",
            "year",
            "track",
            "batch",
            "uni_name",
            "major_name",
            "major_raw",
            "min_score",
            "min_rank",
            "plan",
            "subject_req",
            "source",
            "fetched_at",
        ),
        ("prov_id", "year", "track", "uni_name", "major_name", "min_score"),
        ("prov_id", "year", "track", "uni_name", "major_name"),
    ),
    "plan": TableSpec(
        "plan",
        (
            "prov_id",
            "year",
            "track",
            "batch",
            "uni_name",
            "major_name",
            "plan",
            "tuition",
            "subject_req",
            "source",
            "fetched_at",
        ),
        ("prov_id", "year", "track", "uni_name", "plan"),
        ("prov_id", "year", "track", "uni_name", "major_name"),
    ),
    "university_meta": TableSpec(
        "university_meta",
        # uni_code = 官方院校代码，跨年跨表关联的稳定主键
        ("uni_code", "uni_name", "aliases", "uni_prov", "city", "level", "kind", "nature", "source", "fetched_at"),
        ("uni_name",),
        ("uni_code", "uni_name"),
    ),
}
