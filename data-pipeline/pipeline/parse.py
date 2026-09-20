"""解析器注册表：新增格式只需在这里登记。"""

from __future__ import annotations

from pathlib import Path

from pipeline.config import SourceSpec
from pipeline.providers.hf_csv import parse_hf_csv
from pipeline.providers.html_table import parse_html_table
from pipeline.providers.manual import parse_manual
from pipeline.providers.prov_pdf import parse_prov_pdf
from pipeline.providers.xls import parse_xls

PARSERS: dict[str, object] = {
    "html_table": parse_html_table,
    "xls": parse_xls,
    "manual": parse_manual,
    "hf_csv": parse_hf_csv,
    "prov_pdf": parse_prov_pdf,
}

# 不联网、只读人工下载副本的解析器
LOCAL_ONLY_PARSERS = {"hf_csv", "prov_pdf"}

# 最近一次解析的统计：rows / dropped / parser
LAST_STATS: dict[str, object] = {}


def parse_source(spec: SourceSpec, path: Path) -> list[dict]:
    if spec.parser not in PARSERS:
        raise KeyError(f"未知解析器: {spec.parser}")
    rows, dropped = PARSERS[spec.parser](path, spec.options)
    LAST_STATS.update({"parser": spec.parser, "rows": len(rows), "dropped": dropped})
    if not rows:
        raise ValueError(
            f"{spec.kind} 解析出 0 行（解析器={spec.parser}, 来源={path}）——"
            f"通常是表头变了，请核对配置 columns/column_map"
        )
    return rows
