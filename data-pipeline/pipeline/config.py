"""省份配置：新增一省 = 新增一份 toml，不改代码。"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path

CONFIG_DIR = Path(__file__).resolve().parent.parent / "configs" / "provinces"


@dataclass(frozen=True)
class SourceSpec:
    kind: str  # rank_table | batch_lines | admission | plan
    url_template: str  # 可含 {year} 占位
    parser: str  # html_table | xls | prov_pdf | manual
    options: dict = field(default_factory=dict)
    # 考试院 PDF / 动态页链接含随机 hash，无法用 {year} 模板推导，按年份逐个登记
    url_overrides: dict = field(default_factory=dict)
    # 源数据不可信时停用（保留配置与说明，跑批时跳过）
    disabled: bool = False
    note: str = ""


@dataclass(frozen=True)
class ProvinceConfig:
    prov_id: str
    name: str
    mode: str  # 3+1+2 | 3+3
    sources: list[SourceSpec]
    # 高考满分：海南标准分 900，其余省份默认 750
    max_score: int = 750


def load_province_config(prov_id: str) -> ProvinceConfig:
    path = CONFIG_DIR / f"{prov_id}.toml"
    raw = tomllib.loads(path.read_text(encoding="utf-8"))
    return ProvinceConfig(
        prov_id=prov_id,
        name=raw["name"],
        mode=raw["mode"],
        sources=[SourceSpec(**s) for s in raw.get("sources", [])],
        max_score=int(raw.get("max_score", 750)),
    )


def list_provinces() -> list[str]:
    if not CONFIG_DIR.exists():
        return []
    return sorted(p.stem for p in CONFIG_DIR.glob("*.toml"))
