# 官方高考数据接入管道（TOP20 大省）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建一条可复现的采集管道，把 TOP20 高考大省的官方一分一段表、批次线、投档线抓取归一化为标准表，校验后生成 Web 与 iOS 双端消费的数据产物。

**Architecture:** 配置驱动的 Python 管道 —— `configs/provinces/<prov>.toml` 声明来源与解析器，`fetchers` 抓原始页存档到 `raw/`，可插拔 `parsers`（html_table / xls / pdf_text / manual）解析，`normalizers` 归一到 6 张标准 CSV，`validate` 三级校验后进 `build` 生成 `src/data/generated/officialDataset.json`（Web）与 `bundle.json`（iOS）。新增一省只加配置，不改核心代码。

**Tech Stack:** Python 3.14（`tomllib` 内置）+ pandas + requests + beautifulsoup4 + pdfplumber + pytest；产物由 `npm run data:build` 包装调用。

**Spec:** `docs/superpowers/specs/2026-09-18-official-data-pipeline-design.md`

## Global Constraints

- 省份 id 沿用 `src/data/provinces.ts` 现值（`henan`、`guangdong`、`shandong`、`sichuan` …）；新增省不得改名。
- `track` 只有两个合法值：`phy` / `his`；3+3 省份统一写 `phy`。
- 目标年份由运行日期推导，禁止硬编码：`month >= 6 → target_year = year`，否则 `year - 1`；`history_years = target_year-3 .. target_year-1`。
- 抓取合规：遵守 `robots.txt`，同域名请求间隔 ≥ 1s，仅取公开页面；合订本只抽取统计字段（院校/专业/科类/计划数/选科/学费），不做全文复制。
- 产物行必须带 `source`（来源 URL）与 `fetched_at`（ISO8601），可追溯。
- 任何官方数据缺失时 App 必须回退到现推算逻辑，不得出现空数据或崩溃。
- 所有脚本在仓库根目录执行；`raw/` 加入 `.gitignore`（体积大）。

---

### Task 1: 骨架、依赖与年份滚动

**Files:**
- Create: `data-pipeline/requirements.txt`
- Create: `data-pipeline/pipeline/years.py`
- Create: `data-pipeline/pipeline/config.py`
- Create: `data-pipeline/tests/test_years.py`
- Create: `data-pipeline/tests/test_config.py`
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/package.json`（新增 `data:build` / `data:validate`）
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/.gitignore`（忽略 `raw/`）

**Interfaces:**
- Produces: `resolve_years(today: date | None = None) -> YearContext`；`YearContext` 为 dataclass：`target_year: int`、`history_years: list[int]`、`current_year: int`（= `target_year`）
- Produces: `load_province_config(prov_id: str) -> ProvinceConfig`；`ProvinceConfig` 字段：`prov_id`、`name`、`mode`、`sources: list[SourceSpec]`；`SourceSpec` 字段：`kind`（`rank_table|batch_lines|admission|plan`）、`url_template`、`parser`、`options: dict`

- [ ] **Step 1: 写失败测试（年份滚动）**

```python
# data-pipeline/tests/test_years.py
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_years.py -v`
Expected: FAIL，`ModuleNotFoundError: No module named 'pipeline'`

- [ ] **Step 3: 安装依赖并建骨架**

```bash
cd data-pipeline && python3 -m pip install -r requirements.txt
```

`requirements.txt` 内容固定为：

```
pandas>=2.2
requests>=2.32
beautifulsoup4>=4.12
lxml>=5.2
pdfplumber>=0.11
pytest>=8.2
```

- [ ] **Step 4: 实现 `years.py` 与 `config.py`**

```python
# data-pipeline/pipeline/years.py
from __future__ import annotations
from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class YearContext:
    target_year: int
    history_years: list[int]
    current_year: int


def resolve_years(today: date | None = None) -> YearContext:
    today = today or date.today()
    target = today.year if today.month >= 6 else today.year - 1
    return YearContext(
        target_year=target,
        history_years=[target - 3, target - 2, target - 1],
        current_year=target,
    )
```

```python
# data-pipeline/pipeline/config.py
from __future__ import annotations
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

CONFIG_DIR = Path(__file__).resolve().parent.parent / "configs" / "provinces"


@dataclass(frozen=True)
class SourceSpec:
    kind: str            # rank_table | batch_lines | admission | plan
    url_template: str    # 可含 {year} 占位
    parser: str          # html_table | xls | pdf_text | manual
    options: dict = field(default_factory=dict)


@dataclass(frozen=True)
class ProvinceConfig:
    prov_id: str
    name: str
    mode: str
    sources: list[SourceSpec]


def load_province_config(prov_id: str) -> ProvinceConfig:
    path = CONFIG_DIR / f"{prov_id}.toml"
    raw = tomllib.loads(path.read_text(encoding="utf-8"))
    return ProvinceConfig(
        prov_id=prov_id,
        name=raw["name"],
        mode=raw["mode"],
        sources=[SourceSpec(**s) for s in raw.get("sources", [])],
    )
```

- [ ] **Step 5: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_years.py tests/test_config.py -v`
Expected: PASS（2+ 项）

- [ ] **Step 6: 提交**

```bash
git add data-pipeline package.json .gitignore
git commit -m "feat(pipeline): add skeleton, dependency pins and year rolling"
```

---

### Task 2: staging 数据契约与读写

**Files:**
- Create: `data-pipeline/pipeline/contract.py`
- Create: `data-pipeline/pipeline/staging.py`
- Create: `data-pipeline/tests/test_staging.py`

**Interfaces:**
- Consumes: `YearContext`
- Produces: `TABLES: dict[str, TableSpec]`（`rank_table` / `batch_lines` / `admission` / `major_admission` / `plan` / `university_meta`）；`write_table(df, kind, staging_dir)`、`read_table(kind, staging_dir)`、`TableSpec.columns`、`TableSpec.required`

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_staging.py
import pandas as pd
from pipeline.staging import write_table, read_table
from pipeline.contract import TABLES


def test_roundtrip_preserves_columns(tmp_path):
    df = pd.DataFrame(
        [{"prov_id": "henan", "year": 2025, "track": "phy", "score": 600, "rank": 1000, "cum_count": 120}]
    )
    write_table(df, "rank_table", tmp_path)
    out = read_table("rank_table", tmp_path)
    assert list(out.columns) == TABLES["rank_table"].columns
    assert len(out) == 1


def test_missing_required_column_rejected(tmp_path):
    df = pd.DataFrame([{"prov_id": "henan", "score": 600}])
    try:
        write_table(df, "rank_table", tmp_path)
    except ValueError as e:
        assert "rank" in str(e)
    else:
        raise AssertionError("应拒绝缺列")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_staging.py -v`
Expected: FAIL

- [ ] **Step 3: 实现契约**

```python
# data-pipeline/pipeline/contract.py
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
        ("prov_id", "year", "track", "special", "undergrad", "college", "candidates", "ug_plan", "source", "fetched_at"),
        ("prov_id", "year", "track", "special", "undergrad", "college"),
        ("prov_id", "year", "track"),
    ),
    "admission": TableSpec(
        "admission",
        ("prov_id", "year", "track", "batch", "uni_name", "uni_raw", "min_score", "min_rank", "plan", "source", "fetched_at"),
        ("prov_id", "year", "track", "uni_name", "min_score"),
        ("prov_id", "year", "track", "uni_name"),
    ),
    "major_admission": TableSpec(
        "major_admission",
        ("prov_id", "year", "track", "batch", "uni_name", "major_name", "major_raw", "min_score", "min_rank", "plan", "subject_req", "source", "fetched_at"),
        ("prov_id", "year", "track", "uni_name", "major_name", "min_score"),
        ("prov_id", "year", "track", "uni_name", "major_name"),
    ),
    "plan": TableSpec(
        "plan",
        ("prov_id", "year", "track", "batch", "uni_name", "major_name", "plan", "tuition", "subject_req", "source", "fetched_at"),
        ("prov_id", "year", "track", "uni_name", "plan"),
        ("prov_id", "year", "track", "uni_name", "major_name"),
    ),
    "university_meta": TableSpec(
        "university_meta",
        ("uni_name", "aliases", "prov", "city", "level", "kind", "official_url"),
        ("uni_name",),
        ("uni_name",),
    ),
}
```

- [ ] **Step 4: 实现 `staging.py`**

```python
# data-pipeline/pipeline/staging.py
from __future__ import annotations
from pathlib import Path
import pandas as pd
from pipeline.contract import TABLES


def table_path(kind: str, staging_dir: Path) -> Path:
    return Path(staging_dir) / f"{kind}.csv"


def write_table(df: pd.DataFrame, kind: str, staging_dir: Path) -> Path:
    spec = TABLES[kind]
    missing = [c for c in spec.required if c not in df.columns]
    if missing:
        raise ValueError(f"{kind} 缺少必需列: {missing}")
    out = df.reindex(columns=list(spec.columns))
    Path(staging_dir).mkdir(parents=True, exist_ok=True)
    path = table_path(kind, staging_dir)
    out.to_csv(path, index=False, encoding="utf-8")
    return path


def read_table(kind: str, staging_dir: Path) -> pd.DataFrame:
    path = table_path(kind, staging_dir)
    if not path.exists():
        return pd.DataFrame(columns=list(TABLES[kind].columns))
    return pd.read_csv(path, encoding="utf-8")
```

- [ ] **Step 5: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_staging.py -v`
Expected: PASS（2 项）

- [ ] **Step 6: 提交**

```bash
git add data-pipeline/pipeline data-pipeline/tests
git commit -m "feat(pipeline): add staging contract for six standard tables"
```

---

### Task 3: 抓取层（限速 + robots + raw 存档）

**Files:**
- Create: `data-pipeline/pipeline/fetch.py`
- Create: `data-pipeline/tests/test_fetch.py`
- Create: `data-pipeline/tests/fixtures/sample_table.html`

**Interfaces:**
- Consumes: `SourceSpec`、`YearContext`
- Produces: `fetch_source(spec: SourceSpec, year: int, force: bool = False) -> Path`；`resolve_url(spec, year) -> str`

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_fetch.py
from pipeline.fetch import resolve_url, fetch_source, OFFLINE
from pipeline.config import SourceSpec
import os


def test_resolve_url_replaces_year():
    spec = SourceSpec("rank_table", "https://example.org/{year}/rank.html", "html_table")
    assert resolve_url(spec, 2025) == "https://example.org/2025/rank.html"


def test_offline_mode_uses_fixture(monkeypatch, tmp_path):
    monkeypatch.setenv("GAOKAO_OFFLINE", "1")
    monkeypatch.setenv("GAOKAO_RAW_DIR", str(tmp_path))
    spec = SourceSpec("rank_table", "file:tests/fixtures/sample_table.html", "html_table")
    path = fetch_source(spec, 2025)
    assert path.exists() and path.read_text(encoding="utf-8")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_fetch.py -v`
Expected: FAIL

- [ ] **Step 3: 实现 `fetch.py`**

```python
# data-pipeline/pipeline/fetch.py
from __future__ import annotations
import os
import time
from pathlib import Path
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser
import requests
from pipeline.config import SourceSpec

RAW_DIR = Path(os.environ.get("GAOKAO_RAW_DIR", Path(__file__).resolve().parent.parent / "raw"))
OFFLINE = os.environ.get("GAOKAO_OFFLINE") == "1"
UA = "zhiyuantong-data-pipeline/0.1 (educational use; contact: local)"
_last_hit: dict[str, float] = {}
_robots: dict[str, RobotFileParser] = {}


def resolve_url(spec: SourceSpec, year: int) -> str:
    return spec.url_template.format(year=year)


def _robots_allows(url: str) -> bool:
    host = urlparse(url).netloc
    rp = _robots.get(host)
    if rp is None:
        rp = RobotFileParser()
        try:
            rp.set_url(f"{urlparse(url).scheme}://{host}/robots.txt")
            rp.read()
        except Exception:
            return True
        _robots[host] = rp
    return rp.can_fetch(UA, url)


def fetch_source(spec: SourceSpec, year: int, force: bool = False) -> Path:
    url = resolve_url(spec, year)
    if url.startswith("file:"):
        local = Path(url.removeprefix("file:"))
        return local if local.is_absolute() else Path.cwd() / local
    dest = RAW_DIR / spec.kind / str(year) / (urlparse(url).path.strip("/").replace("/", "_") or "index.html")
    if dest.exists() and not force:
        return dest
    if OFFLINE:
        raise RuntimeError(f"离线模式下缺少存档: {url} -> {dest}")
    if not _robots_allows(url):
        raise RuntimeError(f"robots.txt 禁止抓取: {url}")
    host = urlparse(url).netloc
    gap = time.monotonic() - _last_hit.get(host, 0.0)
    if gap < 1.0:
        time.sleep(1.0 - gap)
    resp = requests.get(url, headers={"User-Agent": UA}, timeout=30)
    resp.raise_for_status()
    _last_hit[host] = time.monotonic()
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(resp.content)
    return dest
```

- [ ] **Step 4: 建 fixture 并跑测试**

`tests/fixtures/sample_table.html` 内容为一个最小 HTML 表格（分数/位次两列，5 行），供后续解析器复用。

Run: `cd data-pipeline && python3 -m pytest tests/test_fetch.py -v`
Expected: PASS（2 项）

- [ ] **Step 5: 提交**

```bash
git add data-pipeline/pipeline/fetch.py data-pipeline/tests
git commit -m "feat(pipeline): add rate-limited fetcher with raw archiving"
```

---

### Task 4: 可插拔解析器（html_table / xls）

**Files:**
- Create: `data-pipeline/pipeline/providers/base.py`
- Create: `data-pipeline/pipeline/providers/html_table.py`
- Create: `data-pipeline/pipeline/providers/xls.py`
- Create: `data-pipeline/pipeline/parse.py`
- Create: `data-pipeline/tests/test_parse.py`

**Interfaces:**
- Consumes: `fetch_source` 返回的 `Path`、`SourceSpec.options`
- Produces: `PARSERS: dict[str, Parser]`；`parse_source(spec, path) -> list[dict]`（原始行 dict，未归一化）

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_parse.py
from pathlib import Path
from pipeline.parse import parse_source
from pipeline.config import SourceSpec


def test_parse_html_table():
    spec = SourceSpec("rank_table", "x", "html_table", {"columns": ["score", "rank"]})
    rows = parse_source(spec, Path("tests/fixtures/sample_table.html"))
    assert rows and rows[0]["score"] == "700"
    assert rows[0]["rank"] == "58"


def test_unknown_parser_raises():
    spec = SourceSpec("rank_table", "x", "nope")
    try:
        parse_source(spec, Path("tests/fixtures/sample_table.html"))
    except KeyError:
        pass
    else:
        raise AssertionError("未知解析器应报错")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_parse.py -v`
Expected: FAIL

- [ ] **Step 3: 实现解析器与注册**

`providers/html_table.py` 用 BeautifulSoup 取首个 `<table>`，表头归一化（去空白/全角），按 `options.columns` 做列名模糊匹配（复用与 iOS `ColumnKey` 同思路的中英文键列表）；`providers/xls.py` 用 `pandas.read_excel` 读首个工作表转 dict 列表。

```python
# data-pipeline/pipeline/parse.py
from __future__ import annotations
from pathlib import Path
from pipeline.config import SourceSpec
from pipeline.providers.html_table import parse_html_table
from pipeline.providers.xls import parse_xls

PARSERS = {"html_table": parse_html_table, "xls": parse_xls}


def parse_source(spec: SourceSpec, path: Path) -> list[dict]:
    if spec.parser not in PARSERS:
        raise KeyError(f"未知解析器: {spec.parser}")
    return PARSERS[spec.parser](path, spec.options)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_parse.py -v`
Expected: PASS（2 项）

- [ ] **Step 5: 提交**

```bash
git add data-pipeline/pipeline
git commit -m "feat(pipeline): add pluggable html_table and xls parsers"
```

---

### Task 5: 归一化与院校名规范化

**Files:**
- Create: `data-pipeline/pipeline/aliases.py`
- Create: `data-pipeline/pipeline/normalize.py`
- Create: `data-pipeline/configs/university_aliases.csv`
- Create: `data-pipeline/tests/test_normalize.py`

**Interfaces:**
- Consumes: `parse_source` 输出的 `list[dict]`
- Produces: `canonical_name(raw: str) -> str | None`；`normalize_rows(rows, kind, prov_id, year, track, source) -> pd.DataFrame`

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_normalize.py
from pipeline.aliases import canonical_name
from pipeline.normalize import normalize_rows


def test_alias_matches_official_name():
    assert canonical_name("郑州大学(郑州)") == "郑州大学"


def test_unknown_name_returns_none():
    assert canonical_name("某某不存在的大学") is None


def test_normalize_rows_fills_context():
    rows = [{"院校名称": "郑州大学", "最低分": "590", "最低位次": "23000"}]
    df = normalize_rows(rows, "admission", "henan", 2025, "phy", "https://x")
    assert df.loc[0, "uni_name"] == "郑州大学"
    assert df.loc[0, "min_score"] == 590
    assert df.loc[0, "track"] == "phy"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_normalize.py -v`
Expected: FAIL

- [ ] **Step 3: 实现别名表与归一化**

`configs/university_aliases.csv` 首期填入 App 内 `src/data/universities.ts` 的全部院校名（用脚本从该文件导出，保证两边一致）；`canonical_name` 依次尝试：精确匹配 → 去括号后缀 → 去「大学/学院」后缀比较 → 返回 `None`（交由复核队列处理）。

`normalize_rows` 负责：列名映射（中文表头 → 契约列名）、字符串清洗（去空格、全角转半角、数字去千分位）、`track` 归一（`物理|综合|理科|物理类` → `phy`；`历史|文史|文科|历史类` → `his`）、补 `prov_id/year/track/source/fetched_at`。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_normalize.py -v`
Expected: PASS（3 项）

- [ ] **Step 5: 提交**

```bash
git add data-pipeline/pipeline data-pipeline/configs
git commit -m "feat(pipeline): add university alias resolution and row normalization"
```

---

### Task 6: L1 结构校验

**Files:**
- Create: `data-pipeline/pipeline/validate.py`
- Create: `data-pipeline/tests/test_validate.py`

**Interfaces:**
- Consumes: `read_table`
- Produces: `Issue`（`table`、`row_index`、`rule`、`message`、`observed`）；`validate_staging(staging_dir, year_ctx) -> list[Issue]`；`has_blocking(issues) -> bool`

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_validate.py
import pandas as pd
from pipeline.validate import validate_staging, has_blocking
from pipeline.staging import write_table


def test_detects_rank_not_monotonic(tmp_path):
    df = pd.DataFrame([
        {"prov_id": "henan", "year": 2025, "track": "phy", "score": 600, "rank": 1000},
        {"prov_id": "henan", "year": 2025, "track": "phy", "score": 601, "rank": 900},
    ])
    write_table(df, "rank_table", tmp_path)
    issues = validate_staging(tmp_path)
    assert has_blocking(issues)
    assert any(i.rule == "rank_monotonic" for i in issues)


def test_clean_tables_pass(tmp_path):
    df = pd.DataFrame([
        {"prov_id": "henan", "year": 2025, "track": "phy", "score": 601, "rank": 900},
        {"prov_id": "henan", "year": 2025, "track": "phy", "score": 600, "rank": 1000},
    ])
    write_table(df, "rank_table", tmp_path)
    assert not has_blocking(validate_staging(tmp_path))
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_validate.py -v`
Expected: FAIL

- [ ] **Step 3: 实现校验规则**

规则清单（阻断级）：`score_domain`（0–750）、`rank_domain`（>0）、`rank_monotonic`（分数降序时位次单调不减）、`unique_key`（契约唯一键不重复）、`track_domain`（仅 phy/his）、`score_rank_consistency`（同一 `(prov,year,track)` 内分数更高者位次更小，用一分一段表插值比对，偏差 > 5% 报错）。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_validate.py -v`
Expected: PASS（2 项）

- [ ] **Step 5: 提交**

```bash
git add data-pipeline/pipeline/validate.py data-pipeline/tests
git commit -m "feat(pipeline): add blocking structural validation rules"
```

---

### Task 7: 河南适配器（批 1 试点省 A）

**Files:**
- Create: `data-pipeline/configs/provinces/henan.toml`
- Create: `data-pipeline/pipeline/providers/pdf_text.py`
- Create: `data-pipeline/pipeline/run.py`（CLI：`run --prov <id>`）
- Create: `data-pipeline/tests/test_run_henan.py`

**Interfaces:**
- Consumes: Task 1–6 全部接口
- Produces: `python -m pipeline.run --prov henan`；`staging/rank_table.csv`、`batch_lines.csv`、`admission.csv`；`run_report.json`

- [ ] **Step 1: 实地确认来源**

人工访问河南省教育考试院（`haeea.cn`）确认 2023–2025 三年的一分一段表、批次线、本科批投档线页面 URL 与格式（HTML / XLS / PDF）。把结果写进 `configs/provinces/henan.toml`；若某年份页面已下线，该年份标 `"parser": "manual"` 并在 `options.note` 写明获取方式。

- [ ] **Step 2: 写失败测试（端到端跑通）**

```python
# data-pipeline/tests/test_run_henan.py
import json
from pathlib import Path
from pipeline.run import run_province
from pipeline.staging import read_table


def test_henan_pipeline_produces_three_tables(tmp_path):
    report = run_province("henan", staging_dir=tmp_path, offline=True)
    for kind in ("rank_table", "batch_lines", "admission"):
        assert len(read_table(kind, tmp_path)) > 0, kind
    assert report["blocking_issues"] == 0
```

- [ ] **Step 3: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_run_henan.py -v`
Expected: FAIL

- [ ] **Step 4: 实现 `run.py` 与 `pdf_text.py`**

`run.py`：对 `history_years + [target_year]` 逐年遍历 `sources`，`fetch_source` → `parse_source` → `normalize_rows` → 按 kind 合并写表 → `validate_staging` → 写 `run_report.json`（抓取条数、阻断问题数、复核条目数）。
`providers/pdf_text.py`：用 `pdfplumber` 抽取首个表格文本，按行列切分返回 dict 列表；扫描件（无文字层）直接抛错，提示降级 `manual`。

- [ ] **Step 5: 跑通并核对真实数值**

Run: `cd data-pipeline && python3 -m pipeline.run --prov henan`
Expected: `staging/` 三表非空；`run_report.json` 中 `blocking_issues == 0`。抽查 3 所院校的最低分与省考试院页面人工比对一致。

- [ ] **Step 6: 提交**

```bash
git add data-pipeline
git commit -m "feat(pipeline): add Henan adapter and CLI runner"
```

---

### Task 8: 广东适配器 + 可复制性验收

**Files:**
- Create: `data-pipeline/configs/provinces/guangdong.toml`
- Create: `data-pipeline/configs/provinces/shandong.toml`
- Create: `data-pipeline/tests/test_run_guangdong.py`

**Interfaces:**
- Consumes: Task 7 的 `run_province`
- Produces: 三省配置；`docs/superpowers/plans/` 之外的验收结论写入 `data-pipeline/REPLICABILITY.md`

- [ ] **Step 1: 实地确认广东来源**

确认广东省教育考试院（`eea.gd.gov.cn`）的一分一段表与本科批投档线 URL/格式；广东投档线可能只给「最低排位」而无分数，需在配置 `options` 中标注 `has_min_rank_only`，归一化时 `min_score` 留空（L1 校验豁免该字段）。

- [ ] **Step 2: 写失败测试**

```python
# data-pipeline/tests/test_run_guangdong.py
from pipeline.run import run_province
from pipeline.staging import read_table


def test_guangdong_pipeline(tmp_path):
    report = run_province("guangdong", staging_dir=tmp_path, offline=True)
    assert len(read_table("rank_table", tmp_path)) > 0
    assert report["blocking_issues"] == 0
```

- [ ] **Step 3: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_run_guangdong.py -v`
Expected: FAIL

- [ ] **Step 4: 写配置（含山东）并跑通**

`shandong.toml` 必须与河南/广东使用**已存在的解析器**（`html_table` / `xls` / `pdf_text` 之一），不得新增任何 `pipeline/` 下的代码文件。3+3 模式省份 `mode = "3+3"`，`track` 统一写 `phy`。

- [ ] **Step 5: 跑三省测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_run_henan.py tests/test_run_guangdong.py -v`
Expected: PASS

- [ ] **Step 6: 记录可复制性结论**

`data-pipeline/REPLICABILITY.md` 写明：新增山东所改动的文件清单（应仅 `configs/provinces/shandong.toml` + 可能的别名表行）、耗时、`pipeline/` 下代码改动行数（应为 0）。**若出现核心代码改动，视为验收未通过，先重构再继续。**

- [ ] **Step 7: 提交**

```bash
git add data-pipeline
git commit -m "feat(pipeline): add Guangdong and Shandong configs, verify replicability"
```

---

### Task 9: L2 交叉校验与 L3 复核队列

**Files:**
- Create: `data-pipeline/pipeline/crosscheck.py`
- Create: `data-pipeline/pipeline/review.py`
- Create: `data-pipeline/tests/test_crosscheck.py`
- Create: `data-pipeline/tests/test_review.py`

**Interfaces:**
- Consumes: `read_table("admission")`
- Produces: `crosscheck(staging_dir, baseline_csv) -> list[Issue]`（非阻断，进队列）；`write_review_queue(issues, path)`、`apply_review_decisions(staging_dir, queue_path)`

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_crosscheck.py
from pipeline.crosscheck import crosscheck


def test_flags_large_deviation(tmp_path):
    # 用最小基线 CSV 构造：郑州大学 2025 物理类最低分 590，管道值为 620
    issues = crosscheck(tmp_path, "tests/fixtures/baseline_min.csv")
    assert any(i.rule == "baseline_score_deviation" for i in issues)
```

```python
# data-pipeline/tests/test_review.py
import pandas as pd
from pipeline.staging import write_table, read_table
from pipeline.review import write_review_queue, apply_review_decisions


def test_decision_fix_overrides_value(tmp_path):
    df = pd.DataFrame([{
        "prov_id": "henan", "year": 2025, "track": "phy", "batch": "本科批",
        "uni_name": "郑州大学", "uni_raw": "郑州大学", "min_score": 620, "min_rank": 23000,
    }])
    write_table(df, "admission", tmp_path)
    queue = pd.DataFrame([{
        "table": "admission", "row_key": "henan|2025|phy|郑州大学", "rule": "baseline_score_deviation",
        "observed": "620", "expected": "590", "source_url": "https://x", "decision": "fix:590",
    }])
    qpath = tmp_path / "review_queue.csv"
    write_review_queue(queue, qpath)
    apply_review_decisions(tmp_path, qpath)
    assert int(read_table("admission", tmp_path).loc[0, "min_score"]) == 590
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_crosscheck.py tests/test_review.py -v`
Expected: FAIL

- [ ] **Step 3: 准备基线数据**

下载开源数据集 `EvanYao826/china-university-admission` 的 SQLite（或 `fangge/gaokaoscore` 的广东数据）到 `data-pipeline/baseline/`（不进 git，`.gitignore`），导出为 `baseline/admission_baseline.csv`，列：`prov_name, year, track, uni_name, min_score, min_rank`。**仅供交叉校验与冷启动参考，不作为最终数据源。**

- [ ] **Step 4: 实现交叉校验与复核队列**

偏差阈值：分数 > 8 分，或位次相对偏差 > 15% → 进队列。命中率 < 60% 视为解析器失效，`run_province` 直接失败（不静默通过）。队列 CSV 列：`table,row_key,rule,observed,expected,source_url,decision`（`decision` ∈ `accept|fix:<值>|drop`，留空为待处理）。

- [ ] **Step 5: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_crosscheck.py tests/test_review.py -v`
Expected: PASS

- [ ] **Step 6: 清空河南/广东复核队列**

人工逐条核对 `review_queue.csv`，填入 `decision`；院校名未匹配项补充到 `configs/university_aliases.csv`。

- [ ] **Step 7: 提交**

```bash
git add data-pipeline
git commit -m "feat(pipeline): add cross-check baseline and human review queue"
```

---

### Task 10: 招生计划（合订本）通道

**Files:**
- Create: `data-pipeline/configs/provinces/sichuan.toml`
- Create: `data-pipeline/pipeline/providers/manual.py`
- Create: `data-pipeline/pipeline/plan.py`
- Create: `data-pipeline/tests/test_plan.py`

**Interfaces:**
- Consumes: `fetch_source`、`parse_source`
- Produces: `build_plan(prov_id, year, staging_dir) -> pd.DataFrame`（写入 `staging/plan.csv`）；L1/L2/L3 三级策略见 spec §7

- [ ] **Step 1: 实地确认合订本形态**

- 四川：确认 `plan.sceea.cn` 目录结构，判定为 **L1 在线版**，写 `sichuan.toml`（`parser = "html_table"`，分页由 `options.pages` 驱动）。
- 河南：确认《招生考试之友》PDF 是否为文字层；是 → **L2**（人工下载放 `raw/plan/2025/`，`parser = "pdf_text"`）；否 → **L3**（`parser = "manual"`，填 `manual/plan_henan_2025.csv` 模板）。判定结果写入配置 `options.level`。

- [ ] **Step 2: 写失败测试**

```python
# data-pipeline/tests/test_plan.py
from pipeline.plan import build_plan
from pipeline.staging import read_table


def test_sichuan_plan_rows(tmp_path):
    build_plan("sichuan", 2025, tmp_path)
    df = read_table("plan", tmp_path)
    assert len(df) > 0
    assert df["plan"].notna().all()
```

- [ ] **Step 3: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_plan.py -v`
Expected: FAIL

- [ ] **Step 4: 实现 `plan.py` 与 `manual.py`**

`plan.py`：按配置级别分派 —— L1 分页抓取 HTML 表格；L2 调 `pdfplumber` 抽表（无文字层抛错并提示降级）；L3 读 `manual/` 下人工填写的 CSV。输出统一为 `plan` 契约表，只保留统计字段（院校、专业、科类、计划数、选科、学费），**不落任何说明性原文**。

- [ ] **Step 5: 跑测试确认通过**

Run: `cd data-pipeline && python3 -m pytest tests/test_plan.py -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add data-pipeline
git commit -m "feat(pipeline): add enrollment plan channel with L1/L2/L3 strategies"
```

---

### Task 11: Web 端衔接（内置官方数据集 + 年份滚动）

**Files:**
- Create: `/Users/fengwang/Documents/trae_projects/gaokao/src/data/generated/officialDataset.json`（由管道生成）
- Create: `data-pipeline/pipeline/build_web.py`
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/src/data/provinces.ts:5-7`（`HISTORY_YEARS` / `CURRENT_YEAR` 改为引用 generated）
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/src/App.tsx:80-95`（启动时载入内置官方数据集）
- Create: `data-pipeline/tests/conftest.py`（提供 `staging_fixture`）
- Test: `data-pipeline/tests/test_build_web.py`（仓库无前端测试框架，前端正确性由 `npm run build` 类型检查 + 冒烟验证保证）

**Interfaces:**
- Consumes: `read_table`（staging 六表）、`OfficialDataset` / `RankTable` / `OfficialAdmission`（`src/lib/dataset.ts` 已定义）
- Produces: `build_web(staging_dir, out_dir) -> Path`；产物 JSON 形状与 `OfficialDataset` 完全一致：`{ updatedAt, rankTables: [{provId, year, track, points:[{score,rank}]}], admissions: [{uniName, provId, year, track, score, rank, plan}], employments: [] }`

> 关键简化：`src/lib/dataset.ts` 已有 `findRankTable` / `findAdmission` / `scoreToRank` / `rankToScore`，`src/lib/admission.ts` 已有 `setActiveDataset`。因此**不需要改动推算算法**，只需在启动时把内置数据集作为底表载入，用户导入数据按同键覆盖即可。

- [ ] **Step 1: 建 `conftest.py` 夹具**

```python
# data-pipeline/tests/conftest.py
import pandas as pd
import pytest
from pipeline.staging import write_table


@pytest.fixture
def staging_fixture(tmp_path):
    write_table(pd.DataFrame([
        {"prov_id": "henan", "year": 2026, "track": "phy", "score": 600, "rank": 1000},
        {"prov_id": "henan", "year": 2026, "track": "phy", "score": 590, "rank": 1500},
    ]), "rank_table", tmp_path)
    write_table(pd.DataFrame([{
        "prov_id": "henan", "year": 2025, "track": "phy", "batch": "本科批",
        "uni_name": "郑州大学", "uni_raw": "郑州大学", "min_score": 590, "min_rank": 23000, "plan": 1250,
    }]), "admission", tmp_path)
    return tmp_path
```

- [ ] **Step 2: 写失败测试（Web 产物形状）**

```python
# data-pipeline/tests/test_build_web.py
import json
from pipeline.build_web import build_web


def test_output_matches_official_dataset_shape(tmp_path, staging_fixture):
    path = build_web(staging_fixture, tmp_path)
    data = json.loads(path.read_text(encoding="utf-8"))
    assert set(data) == {"updatedAt", "rankTables", "admissions", "employments"}
    assert set(data["rankTables"][0]) == {"provId", "year", "track", "points"}
    assert set(data["admissions"][0]) == {"uniName", "provId", "year", "track", "score", "rank", "plan"}
```

- [ ] **Step 3: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_build_web.py -v`
Expected: FAIL

- [ ] **Step 4: 实现 `build_web.py`**

按上述形状序列化；`points` 按分数降序；`admissions` 中 `score`/`rank` 取 `min_score`/`min_rank`；`plan` 缺失写 `null`。

- [ ] **Step 5: 前端接入**

`src/App.tsx` 在 `loadDataset()` 之后合并内置数据集：内置为底、用户导入覆盖（`import { OFFICIAL_DATASET } from './data/generated/officialDataset.json'`），再 `setActiveDataset(merged)`。`provinces.ts` 的 `HISTORY_YEARS` / `CURRENT_YEAR` 改为从同目录生成的 `meta.ts` re-export（保持导出名不变，避免大范围改动）。

- [ ] **Step 6: 类型检查与构建**

Run: `cd /Users/fengwang/Documents/trae_projects/gaokao && npm run build`
Expected: `tsc --noEmit` 与 `vite build` 均通过。

- [ ] **Step 7: 冒烟验证**

Run: `npm run dev`，进入首页确认显示「已接入官方数据：2026 年一分一段表 / N 所院校真实投档线」；手动删除某省文件后重跑，确认回退到推算值且无报错。

- [ ] **Step 8: 提交**

```bash
git add data-pipeline src
git commit -m "feat(web): consume built-in official dataset and roll year constants"
```

---

### Task 12: iOS 产物、npm 脚本与端到端验收

**Files:**
- Create: `data-pipeline/pipeline/build_ios.py`
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/package.json`（`data:build` / `data:validate`）
- Modify: `/Users/fengwang/Documents/trae_projects/gaokao/ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json`（由管道重新生成）
- Test: `data-pipeline/tests/test_build_ios.py`

**Interfaces:**
- Consumes: `read_table`
- Produces: `build_ios(staging_dir, out_path) -> Path`；产物键名与现有 `bundle.json` 及 `Dataset.swift` 的 `RankTable` / `Track` 编码保持一致（`score`/`rank` 为 `Double`，`year` 为 `Int`）

- [ ] **Step 1: 写失败测试**

```python
# data-pipeline/tests/test_build_ios.py
import json
from pipeline.build_ios import build_ios


def test_bundle_keys_preserved(tmp_path, staging_fixture):
    path = build_ios(staging_fixture, tmp_path / "bundle.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    assert set(data) >= {"rankTables", "admissions", "updatedAt"}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd data-pipeline && python3 -m pytest tests/test_build_ios.py -v`
Expected: FAIL

- [ ] **Step 3: 实现 `build_ios.py`（保持现有键名与类型）**

先 `cat ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json` 确认现有顶层键与字段类型，**只做数据替换、不改结构**（`Dataset.swift` 无需改动）。

- [ ] **Step 4: 加 npm 脚本**

```json
"data:build": "cd data-pipeline && python3 -m pipeline.run --all && python3 -m pipeline.build",
"data:validate": "cd data-pipeline && python3 -m pytest -q"
```

- [ ] **Step 5: 端到端验收**

Run: `npm run data:validate && npm run data:build && npm run build`
Expected: 测试全绿；`src/data/generated/officialDataset.json` 与 iOS `bundle.json` 更新；`run_report.json` 中河南/广东/山东/四川四省 `blocking_issues == 0`。

- [ ] **Step 6: 提交**

```bash
git add data-pipeline package.json ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json src
git commit -m "feat(ios): generate bundle.json from pipeline and wire npm scripts"
```

---

## 后续批次（本计划之外，按同一流程复制）

批 2 剩余：河北、湖南、安徽、江苏；批 3：湖北、江西、广西、贵州、浙江、云南、陕西、山西、福建、重庆、甘肃、辽宁。每省 = 一份 `configs/provinces/<prov>.toml` + 跑通校验，核心代码零改动。
