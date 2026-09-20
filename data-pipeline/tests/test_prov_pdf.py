"""prov_pdf 解析器单测：核心逻辑走纯函数，另有一个真实 PDF 冒烟用例。"""

from pathlib import Path

import pytest

from pipeline.config import SourceSpec
from pipeline.parse import parse_source
from pipeline.providers.base import MissingArchive
from pipeline.providers.prov_pdf import ensure_local, extract_rank_rows, source_path

HEADER_ROWS = [
    ["分数", "本段人数", "累计人数"],
    ["700", "10", "10"],
    ["699", "20", "30"],
    ["698", "15", "45"],
]


def test_header_path_extracts_three_columns():
    rows, dropped = extract_rank_rows(HEADER_ROWS, {"columns": ["score", "cum_count", "rank"]})
    assert rows == [
        {"score": "700", "cum_count": "10", "rank": "10"},
        {"score": "699", "cum_count": "20", "rank": "30"},
        {"score": "698", "cum_count": "15", "rank": "45"},
    ]
    assert dropped == 0


def test_positional_path_without_header():
    rows, dropped = extract_rank_rows(
        [["700", "10", "10"], ["699", "20", "30"]], {"columns": ["score", "cum_count", "rank"]}
    )
    assert [r["score"] for r in rows] == ["700", "699"]
    assert [r["rank"] for r in rows] == ["10", "30"]


def test_multicolumn_layout_splits_records():
    # 同一物理行横排两组「分数 本段人数 累计人数」
    rows, _ = extract_rank_rows(
        [["700", "10", "10", "699", "20", "30"]], {"columns": ["score", "cum_count", "rank"]}
    )
    assert rows == [
        {"score": "700", "cum_count": "10", "rank": "10"},
        {"score": "699", "cum_count": "20", "rank": "30"},
    ]


def test_explicit_column_index():
    options = {"score_col": 1, "cum_count_col": 2, "rank_col": 3}
    rows, dropped = extract_rank_rows([["1", "700", "10", "10"], ["第", "1", "页"]], options)
    assert rows == [{"score": "700", "cum_count": "10", "rank": "10"}]
    assert dropped == 1  # 页脚凑不满一行


def test_rank_derived_from_segment_counts():
    rows, _ = extract_rank_rows([["700", "10"], ["699", "20"], ["698", "15"]], {"columns": ["score", "cum_count"]})
    assert [r["rank"] for r in rows] == ["10", "30", "45"]
    assert [r["score"] for r in rows] == ["700", "699", "698"]


def test_score_out_of_domain_is_dropped():
    rows, dropped = extract_rank_rows([["9000", "10", "10"], ["700", "10", "10"]], {})
    assert [r["score"] for r in rows] == ["700"]
    assert dropped == 1


def test_duplicate_scores_deduped():
    # PDF 跨页续表会重复同一分数行，只保留首次出现
    rows, dropped = extract_rank_rows([["700", "10", "10"], ["700", "10", "10"], ["699", "20", "30"]], {})
    assert [r["score"] for r in rows] == ["700", "699"]
    assert dropped == 1


def test_repeated_header_rows_are_skipped():
    rows, _ = extract_rank_rows(
        HEADER_ROWS + [["分数", "本段人数", "累计人数"], ["697", "5", "50"], ["备注：本表含政策性加分", "", ""]], {}
    )
    assert [r["score"] for r in rows] == ["700", "699", "698", "697"]


def test_mismatched_stride_raises():
    # 显式步长与 columns 数量对不齐时必须报错，避免静默取错列
    with pytest.raises(ValueError, match="col_stride"):
        extract_rank_rows([["700", "10", "10", "1"], ["699", "20", "30", "2"]], {"col_stride": 4})


def test_missing_archive_hint():
    dest = Path("/tmp/nope/rank_table_his.pdf")
    with pytest.raises(MissingArchive, match="缺少本地副本"):
        ensure_local("https://example.org/a.pdf", dest)


def test_source_path_layout():
    assert source_path("rank_table", 2025, "henan", "his").name == "rank_table_his.pdf"


def _build_pdf(lines: list[str]) -> bytes:
    """手工拼一个最小 PDF：中文需要用嵌入字体，这里的数据行只用数字，标题用英文列名。"""
    content = ["BT", "/F1 10 Tf", "14 TL", "50 750 Td"]
    for line in lines:
        content.append(f"({line}) Tj T*")
    content.append("ET")
    stream = "\n".join(content).encode("latin-1")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets: list[int] = []
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    size = len(objects) + 1
    out += f"xref\n0 {size}\n".encode() + b"0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {size} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    return bytes(out)


def test_parse_real_pdf_end_to_end(tmp_path):
    path = tmp_path / "rank_table_his.pdf"
    path.write_bytes(
        _build_pdf(["score segment_count cumulative_count", "700   10   10", "699   20   30", "698   15   45"])
    )
    spec = SourceSpec("rank_table", "file://rank", "prov_pdf", {"columns": ["score", "cum_count", "rank"]})
    rows = parse_source(spec, path)
    assert [r["score"] for r in rows] == ["700", "699", "698"]
    assert [r["rank"] for r in rows] == ["10", "30", "45"]
