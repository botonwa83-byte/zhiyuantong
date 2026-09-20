from datetime import date

from pipeline.years import resolve_years


def test_after_june_uses_current_year():
    ctx = resolve_years(date(2026, 9, 18))
    assert ctx.target_year == 2026
    assert ctx.current_year == 2026
    assert ctx.history_years == [2023, 2024, 2025]


def test_before_june_uses_previous_year():
    ctx = resolve_years(date(2026, 3, 1))
    assert ctx.target_year == 2025
    assert ctx.history_years == [2022, 2023, 2024]


def test_default_is_today(monkeypatch):
    class FakeDate(date):
        @classmethod
        def today(cls):
            return date(2027, 7, 1)

    monkeypatch.setattr("pipeline.years.date", FakeDate)
    assert resolve_years().target_year == 2027
