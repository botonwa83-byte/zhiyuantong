"""HTML 表格解析器：省站最常见的形态。返回 (行, 因缺列被丢弃的行数)。"""

from __future__ import annotations

from pathlib import Path

from bs4 import BeautifulSoup

from pipeline.providers.base import apply_column_map


def parse_html_table(path: Path, options: dict) -> tuple[list[dict], int]:
    soup = BeautifulSoup(Path(path).read_text(encoding="utf-8", errors="ignore"), "html.parser")
    tables = soup.find_all("table")
    index = options.get("table_index", 0)
    if not tables or index >= len(tables):
        return [], 0

    rows = [[c.get_text(strip=True) for c in tr.find_all(["th", "td"])] for tr in tables[index].find_all("tr")]
    rows = [r for r in rows if r]
    if len(rows) < 2:
        return [], 0

    header_idx = options.get("header_row", 0)
    headers = rows[header_idx]
    body = rows[header_idx + 1 :]
    return apply_column_map(headers, body, options.get("column_map"), list(options.get("columns", [])))
