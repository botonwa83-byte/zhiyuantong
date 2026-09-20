"""解析器共享：表头 → 契约列的匹配（与 iOS ColumnKey 同一思路）。

匹配顺序：先全等，再子串；子串阶段按调用方给出的 wanted 顺序定优先级。
绝不使用「短表头反向包含长关键词」，否则「人数」会同时命中 plan 与 cum_count。
"""

from __future__ import annotations

from pathlib import Path

COLUMN_KEYS: dict[str, list[str]] = {
    "score": ["分数", "总分", "成绩", "投档分", "录取分", "最低分", "文化分", "score", "minscore"],
    "min_score": ["最低分", "投档最低分", "最低投档分", "录取最低分", "分数", "min_score"],
    "rank": ["位次", "最低位次", "排名", "名次", "累计人数", "累计位次", "rank", "minrank"],
    "min_rank": ["最低位次", "投档最低位次", "位次", "min_rank"],
    "cum_count": ["本段人数", "段内人数", "本段", "人数", "count"],
    "uni_name": ["院校名称", "学校名称", "高校名称", "招生院校", "院校", "学校", "高校", "university", "school"],
    "uni": ["院校名称", "学校名称", "高校名称", "招生院校", "院校", "学校", "高校", "university", "school"],
    "prov_id": ["省份", "招生省份", "省市", "省", "province", "prov"],
    "prov": ["省份", "招生省份", "省市", "省", "province", "prov"],
    "track": ["科类", "类别", "科目", "文理", "选科", "track", "category"],
    "year": ["年份", "年度", "年", "year"],
    "batch": ["录取批次", "批次名称", "批次", "batch"],
    "plan": ["计划数", "招生计划", "计划人数", "招生人数", "计划", "plan"],
    "major_name": ["专业名称", "招生专业", "专业", "major"],
    "subject_req": ["选科要求", "选考科目", "科目要求", "subject"],
    "tuition": ["学费", "收费标准", "tuition"],
    "special": ["特殊类型招生控制线", "特殊类型", "强基线", "special"],
    "undergrad": ["本科批控制线", "本科批", "本科线", "本科", "undergrad"],
    "college": ["专科批控制线", "专科批", "专科线", "高职高专", "college"],
    "candidates": ["报考人数", "考生人数", "报名人数", "candidates"],
    "ug_plan": ["本科招生计划", "本科计划", "ug_plan"],
}

# 子串阶段的显式优先级：先匹配到的先占位。全等阶段不受此顺序影响。
MATCH_PRIORITY: list[str] = [
    "min_score", "score", "min_rank", "rank", "cum_count", "special", "undergrad",
    "college", "candidates", "ug_plan", "plan", "uni_name", "uni", "prov_id", "prov",
    "major_name", "subject_req", "tuition", "track", "batch", "year",
]


class MissingArchive(RuntimeError):
    """本地人工下载副本缺失：需要用户手动下载，不算抓取失败。"""


def local_dataset_path(kind: str, year: int, prov_id: str, dataset: str, ext: str = "csv") -> Path:
    """人工下载的本地副本路径：raw/<省id>/<年>/<kind>_<dataset>.<ext>。"""
    from pipeline import fetch as fetch_mod  # 延迟导入，避免与 fetch 形成循环依赖

    return fetch_mod.RAW_DIR / prov_id / str(year) / f"{kind}_{dataset}.{ext}"


def archive_dest(spec, year: int, prov_id: str) -> Path | None:
    """来源在本地的目标路径；非本地人工下载类来源返回 None。"""
    local_only = {"hf_csv": "csv", "prov_pdf": "pdf"}
    ext = local_only.get(getattr(spec, "parser", ""))
    if not ext:
        return None
    return local_dataset_path(spec.kind, year, prov_id, spec.options.get("dataset", spec.kind), ext)


def normalize_header(text: str) -> str:
    out = str(text).strip().lower()
    for ch in (" ", "\u3000", "_", "-", "（", "）", "(", ")", "："):
        out = out.replace(ch, "")
    return out


def match_columns(
    headers: list[str],
    wanted: list[str],
    keys_map: dict[str, list[str]] | None = None,
) -> dict[str, int]:
    """把表头映射到契约列名；匹配不到则缺失。同一列不会被两个契约名抢占。"""
    keys_map = keys_map or COLUMN_KEYS
    norm = [normalize_header(h) for h in headers]
    mapping: dict[str, int] = {}
    taken: set[int] = set()

    ordered = [w for w in MATCH_PRIORITY if w in wanted]
    ordered += [w for w in wanted if w not in ordered]

    for want in ordered:  # 全等优先
        keys = [normalize_header(k) for k in keys_map.get(want, [want])]
        for i, h in enumerate(norm):
            if i in taken or not h:
                continue
            if h in keys:
                mapping[want] = i
                taken.add(i)
                break

    for want in ordered:  # 再子串
        if want in mapping:
            continue
        keys = [normalize_header(k) for k in keys_map.get(want, [want])]
        for i, h in enumerate(norm):
            if i in taken or not h:
                continue
            if any(k and k in h for k in keys):
                mapping[want] = i
                taken.add(i)
                break

    return mapping


def apply_column_map(
    headers: list[str],
    body: list[list[str]],
    column_map: dict[str, str] | None,
    wanted: list[str],
) -> tuple[list[dict], int]:
    """返回 (行字典列表, 因缺列被丢弃的行数)。"""
    rows: list[dict] = []
    dropped = 0
    if column_map:
        mapping = match_columns(headers, list(column_map.keys()))
        for rec in body:
            row = {column_map[h]: str(rec[i]).strip() for h, i in mapping.items() if i < len(rec)}
            row = {k: v for k, v in row.items() if v and v.lower() != "nan"}
            if row:
                rows.append(row)
            else:
                dropped += 1
        return rows, dropped

    mapping = match_columns(headers, wanted)
    for rec in body:
        row = {want: str(rec[i]).strip() for want, i in mapping.items() if i < len(rec)}
        row = {k: v for k, v in row.items() if v and v.lower() != "nan"}
        if row:
            rows.append(row)
        else:
            dropped += 1
    return rows, dropped
