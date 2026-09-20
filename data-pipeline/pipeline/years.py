"""目标年份推导：禁止在别处硬编码年份。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class YearContext:
    target_year: int
    history_years: list[int]
    current_year: int


def resolve_years(today: date | None = None) -> YearContext:
    """6 月及以后视为当年录取数据已公布，否则只能用到上一年。"""
    today = today or date.today()
    target = today.year if today.month >= 6 else today.year - 1
    return YearContext(
        target_year=target,
        history_years=[target - 3, target - 2, target - 1],
        current_year=target,
    )
