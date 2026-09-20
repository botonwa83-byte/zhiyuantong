import pytest

from pipeline import config as config_mod
from pipeline.config import list_provinces, load_province_config
from pipeline.fetch import resolve_url
from pipeline.parse import PARSERS

SAMPLE = """
name = "河南"
mode = "3+1+2"

[[sources]]
kind = "rank_table"
url_template = "https://example.org/{year}/rank.html"
parser = "html_table"

[[sources]]
kind = "admission"
url_template = "https://example.org/{year}/投档线.xls"
parser = "xls"
options = { sheet = 0 }
"""


def test_loads_sources_from_toml(monkeypatch, tmp_path):
    (tmp_path / "henan.toml").write_text(SAMPLE, encoding="utf-8")
    monkeypatch.setattr(config_mod, "CONFIG_DIR", tmp_path)
    cfg = load_province_config("henan")
    assert cfg.prov_id == "henan"
    assert cfg.name == "河南"
    assert cfg.mode == "3+1+2"
    assert [s.kind for s in cfg.sources] == ["rank_table", "admission"]
    assert cfg.sources[1].options == {"sheet": 0}


@pytest.mark.parametrize("prov_id", list_provinces())
def test_repo_configs_are_runnable(prov_id):
    """仓库里的省份配置必须能加载、能解析出 URL、用的是已登记解析器。"""
    cfg = load_province_config(prov_id)
    assert cfg.name and cfg.mode in {"3+1+2", "3+3"}
    assert cfg.sources
    for spec in cfg.sources:
        assert spec.parser in PARSERS, f"{prov_id} 用了未登记的解析器 {spec.parser}"
        assert resolve_url(spec, 2025).startswith("http"), f"{prov_id} 的 URL 模板不合法"


def test_missing_file_raises(monkeypatch, tmp_path):
    monkeypatch.setattr(config_mod, "CONFIG_DIR", tmp_path)
    try:
        load_province_config("nope")
    except FileNotFoundError:
        pass
    else:
        raise AssertionError("缺少配置文件应报错")
