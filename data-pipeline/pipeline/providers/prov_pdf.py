"""省教育考试院「一分一段表」PDF 解析器（如河南 haeea.cn）。

合规约定：与 hf_csv 一致，**只读取人工下载到 raw/<省>/<年>/ 的本地副本**；
缺失时抛 MissingArchive 给出下载指引，不自动抓取（考试院站点多为防盗链 + robots 限制）。

为什么要这个 provider：第三方数据集（GaokaoCompass）的一分一段表只有物理类，
历史类必须回各省教育考试院原始 PDF，且各省版式不同。

支持两类版式：
1. 规整表格 → pdfplumber.extract_tables 直接取行；
2. 无框线 / 多栏排版 → 退回按坐标聚词成行、按词间距切单元格，再按数值序列切记录。

多栏排版（同一物理行横排了 N 组「分数 本段人数 累计人数」）由 col_stride / 自动步长处理。

配置项（写在 provinces/*.toml 的 [sources.options]）：
- dataset：本地文件名中段，构成 raw/<省>/<年>/<kind>_<dataset>.pdf
- columns：目标契约列，默认 ["score", "cum_count", "rank"]，顺序即每组分列顺序
- column_map：表头 -> 契约列（有表头时用）
- score_col / cum_count_col / rank_col：显式 0 基列号（无表头时用）
- col_stride：每组数据占用的数值个数（显式指定时跳过自动推断）
- derive_rank：只有本段人数时按分数降序累加出累计位次，默认 true
- min_score / max_score：分数合法区间，默认 0-750
- words_only：跳过 extract_tables，直接走坐标聚词方案
- gap / line_tol：聚词时的单元格间距阈值、行内纵向容差（单位 pt）
"""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

from pipeline.providers.base import MissingArchive, apply_column_map, local_dataset_path, match_columns

HEADER_SCAN_ROWS = 12
DEFAULT_WANTED = ["score", "cum_count", "rank"]
SCORE_MIN, SCORE_MAX = 0, 750
LINE_TOL = 2.0
CELL_GAP = 3.0
DIGIT_CLASS = r"[0-9０-９]"
NUMBER_RE = re.compile(rf"{DIGIT_CLASS}[0-9０-９,，]*")
FULLWIDTH = str.maketrans("０１２３４５６７８９，", "0123456789,")


def source_path(kind: str, year: int, prov_id: str, dataset: str, ext: str = "pdf") -> Path:
    return local_dataset_path(kind, year, prov_id, dataset, ext)


def ensure_local(url: str, dest: Path) -> Path:
    if dest.exists():
        return dest
    raise MissingArchive(f"缺少本地副本，请手动下载 {url} 到 {dest}")


def parse_prov_pdf(path: Path, options: dict) -> tuple[list[dict], int]:
    raw_rows = read_pdf_rows(Path(path), options)
    return extract_rank_rows(raw_rows, options)


# --------------------------------------------------------------------------- PDF -> 单元格行


def read_pdf_rows(path: Path, options: dict) -> list[list[str]]:
    import pdfplumber

    rows: list[list[str]] = []
    with pdfplumber.open(str(path)) as pdf:
        for page in pdf.pages:
            rows += _page_rows(page, options)
    return rows


def _page_rows(page, options: dict) -> list[list[str]]:
    if not options.get("words_only"):
        rows = _rows_from_tables(page)
        if rows:
            return rows
    return _rows_from_words(page, gap=float(options.get("gap", CELL_GAP)), tol=float(options.get("line_tol", LINE_TOL)))


def _clean_cell(value) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value).replace("\n", " ")).strip()


def _rows_from_tables(page) -> list[list[str]]:
    out: list[list[str]] = []
    for table in page.extract_tables() or []:
        for raw in table:
            cells = [_clean_cell(c) for c in raw]
            if any(cells):
                out.append(cells)
    return out


def _rows_from_words(page, gap: float, tol: float) -> list[list[str]]:
    """按 top 聚行、按 x0 间距切单元格，兼容无框线与多栏排版。"""
    words = sorted(page.extract_words() or [], key=lambda w: (round(w["top"], 1), w["x0"]))
    lines: list[list[dict]] = []
    for word in words:
        for line in lines:
            if abs(line[0]["top"] - word["top"]) <= tol:
                line.append(word)
                break
        else:
            lines.append([word])

    rows: list[list[str]] = []
    for line in lines:
        cells: list[str] = []
        text = str(line[0]["text"])
        prev = line[0]
        for word in line[1:]:
            if word["x0"] - prev["x1"] > gap:
                cells.append(text)
                text = str(word["text"])
            else:
                text = f"{text} {word['text']}"
            prev = word
        cells.append(text)
        rows.append([_clean_cell(c) for c in cells])
    return rows


# --------------------------------------------------------------------------- 单元格行 -> 契约行


def extract_rank_rows(rows: list[list[str]], options: dict) -> tuple[list[dict], int]:
    """纯函数版核心逻辑（不依赖 PDF），便于单测与逐省调试。"""
    wanted = list(options.get("columns") or DEFAULT_WANTED)
    column_map = options.get("column_map")

    header_idx = _find_header(rows, column_map or wanted)
    if header_idx is not None:
        parsed, dropped = apply_column_map(rows[header_idx], rows[header_idx + 1 :], column_map, wanted)
    else:
        parsed, dropped = _positional_records(rows, wanted, options)

    records, bad = _sanitize(parsed, options)
    return records, dropped + bad


def _find_header(rows: list[list[str]], wanted: list[str]) -> int | None:
    keys = [w for w in wanted if w != "score"]
    for i, cells in enumerate(rows[:HEADER_SCAN_ROWS]):
        mapping = match_columns(cells, wanted)
        if "score" in mapping and any(k in mapping for k in keys):
            return i
    return None


def _to_number(value) -> int | None:
    if value is None:
        return None
    text = str(value).strip().translate(FULLWIDTH).replace(",", "").replace(" ", "")
    if not text:
        return None
    try:
        return int(float(text))
    except ValueError:
        return None


def _row_numbers(cells: list[str]) -> list[int]:
    nums: list[int] = []
    for cell in cells:
        for token in NUMBER_RE.findall(str(cell)):
            value = _to_number(token)
            if value is not None:
                nums.append(value)
    return nums


def _guess_stride(counters: Counter) -> int:
    counts = [c for c in counters if c >= 2]
    if not counts:
        return len(DEFAULT_WANTED)
    total = sum(counters.values())
    for size in (3, 2):
        hit = sum(counters[c] for c in counts if c % size == 0)
        if hit >= total * 0.8:
            return size
    return max(counts, key=lambda c: (counters[c], c))


def _positional_records(rows: list[list[str]], wanted: list[str], options: dict) -> tuple[list[dict], int]:
    """无可用表头时按数值位置切分：支持显式列号、显式步长、自动步长三种方式。"""
    numbered = [(cells, _row_numbers(cells)) for cells in rows]
    numbered = [(cells, nums) for cells, nums in numbered if nums]
    if not numbered:
        return [], len(rows)

    explicit = {name: options.get(f"{name}_col") for name in wanted}
    explicit = {name: int(idx) for name, idx in explicit.items() if idx is not None}

    if explicit and not options.get("col_stride"):
        if len(explicit) != len(wanted):
            missing = [w for w in wanted if w not in explicit]
            raise ValueError(f"已给出部分显式列号，但 {missing} 缺少 <列名>_col；请用 columns 收窄需求")
        stride = max(explicit.values()) + 1
        field_order = wanted
        offsets = [explicit[name] for name in wanted]
    else:
        stride = int(options.get("col_stride") or _guess_stride(Counter(len(nums) for _, nums in numbered)))
        if len(wanted) > stride:
            field_order = wanted[:stride]
        elif stride % len(wanted):
            raise ValueError(
                f"每组数值 {stride} 个与 columns={wanted} 对不齐，请用 col_stride / columns 显式指定版式"
            )
        else:
            field_order = wanted * (stride // len(wanted))
        offsets = list(range(len(field_order)))

    records: list[dict] = []
    dropped = 0
    for _cells, nums in numbered:
        if len(nums) % stride:
            dropped += 1
            continue
        for start in range(0, len(nums), stride):
            chunk = nums[start : start + stride]
            if len(chunk) < stride:
                dropped += 1
                continue
            records.append({name: str(chunk[offset]) for name, offset in zip(field_order, offsets)})
    return records, dropped


def _sanitize(records: list[dict], options: dict) -> tuple[list[dict], int]:
    """分数域校验 + rank 派生 + 同分去重（PDF 跨页续表常出现重复行）。"""
    min_score = int(options.get("min_score", SCORE_MIN))
    max_score = int(options.get("max_score", SCORE_MAX))
    derive = options.get("derive_rank", True)

    out: list[dict] = []
    dropped = 0
    for rec in records:
        score = _to_number(rec.get("score"))
        if score is None or not (min_score <= score <= max_score):
            dropped += 1
            continue
        cum = _to_number(rec.get("cum_count"))
        rank = _to_number(rec.get("rank"))
        if rank is None and cum is None:
            dropped += 1
            continue
        item = {"score": str(score)}
        if cum is not None:
            item["cum_count"] = str(cum)
        if rank is not None:
            item["rank"] = str(rank)
        elif derive:
            item["_derive"] = "1"
        out.append(item)

    if any("_derive" in item for item in out):
        running = 0
        for item in sorted(out, key=lambda r: -int(r["score"])):
            running += int(item.get("cum_count", 0))
            item.pop("_derive", None)
            item["rank"] = str(running)

    seen: set[str] = set()
    deduped: list[dict] = []
    for item in out:
        if item["score"] in seen:
            dropped += 1
            continue
        seen.add(item["score"])
        deduped.append(item)
    return deduped, dropped
