# 设计说明书：官方高考数据接入管道（TOP20 大省）

- 日期：2026-09-18
- 状态：设计中
- 范围：数据管道 + 数据契约；不含 App UI 改动（除必要衔接）

---

## 1. 背景与问题

智愿通 App 当前的核心推算（院校三年线差、位次换算、等效分、录取概率）依赖 `src/data/` 下的人工种子数据：

- `src/data/universities.ts`：`UniversitySeed` 里只有 `base`（相对特殊类型线的基准线差），三年录取记录由 `src/lib/admission.ts` 用确定性算法推导；
- 省份层面 `HISTORY_YEARS = [2022, 2023, 2024]`、`CURRENT_YEAR = 2025`（`src/data/provinces.ts`），已落后于当前年份；
- 一分一段表默认由 `src/lib/ranktable.ts` 做插值估算，非官方分布；
- iOS 侧 `ZhiYuanTong/ZhiYuanTong/Dataset.swift` 已内置 `parseCsv` / `ColumnKey` 列映射，支持用户手动导入；预置的 `Resources/Data/bundle.json` 内容与 Web 端同源。

结论：**推算框架是对的，输入数据是编的。** 缺三个真实输入：一分一段表（位次分布）、院校/专业投档线（最低分+最低位次）、招生计划（计划数）。本设计解决「如何把它们稳定、可复现、可校验地灌进来」。

## 2. 目标与非目标

### 目标

1. 建立可复现的采集管道：一条命令把 TOP20 省份的官方数据抓取、归一化、落盘为结构化中间层（staging）。
2. 数据契约化：定义省份无关的 6 张标准表，所有省份适配器的输出都归一到这套表。
3. 三级校验：结构校验 → 交叉校验（与开源数据集比对）→ 人工复核队列。不可靠的数据宁可不入库。
4. 双端消费：Web（`src/lib/admission.ts` 优先用官方值，缺失回退推算）与 iOS（`bundle.json`）共用同一份产物。
5. 年份滚动：管道按运行日期自动定位目标年份，不再硬编码。
6. 可复制性：新增一省 = 新增一份配置 + 跑通校验，不改核心代码。

### 非目标

- 不做实时抓取服务、不做后端、不做用户账号数据云同步；
- 不承诺招生计划 100% 自动化（合订本为出版物，多数省只有 PDF/纸质）；
- 不改变 App 现有推算算法的数学结构，只替换输入；
- 不覆盖艺体类、强基计划、提前批军事公安等特殊批次（一期只做普通本科批 + 专科批参考线）。

## 3. 数据源调研结论

### 3.1 分层清单

| 层级 | 来源 | 可得内容 | 形态 | 在本设计中的定位 |
| --- | --- | --- | --- | --- |
| A 官方一手 | 各省教育考试院官网 | 一分一段表、批次线（特殊/本科/专科）、本科批平行志愿投档线（最低分+最低位次+计划数） | HTML 表格 / PDF / XLS | **主数据源** |
| A | 阳光高考 `gaokao.chsi.com.cn`（教育部） | 院校库、专业库、院校隶属/层次、部分省一分一段汇总 | HTML | 院校主数据校准（名称规范化、层次、城市） |
| A | 四川 `plan.sceea.cn` | 招生计划合订本**在线版**：在川招生专业及名额（物理类/历史类/艺术/体育） | HTML 目录 | 合订本数字化的首选样板 |
| B 官方聚合 | 中国教育在线 `eol.cn` | 31 省一分一段汇总、投档线汇总 | HTML，格式相对规整 | **补漏 + 交叉校验**；省站不可抓时的降级来源 |
| C 开源数据集 | GitHub `china-university-admission`（SQLite，全国历年分数线）、`gaokaoscore`（广东官方投档数据） | 历年院校分数线 | SQLite / CSV | **冷启动 + 校验基线**，不作为最终数据源 |
| D 商业 API | 阿里云市场 / 聚合数据等 | 全量院校专业线 | API | 备选，有授权成本，一期不启用 |

### 3.2 关键判断

- **C 类不能当最终数据源**：时效与授权均不确定（可能滞后或含错误）。但极适合做「反查基线」——我们抓的某校某年最低分若与开源库偏差超过阈值，直接进复核队列。
- **省站格式差异是最大成本**：同为「投档线」，有的省发 Excel，有的发 HTML，有的只有 PDF 扫描件。因此架构上必须是**配置驱动 + 可插拔解析器**，不能为每个省写一套独立逻辑。
- **合订本（招生计划）价值最高也最难**：它是「计划数变动」修正因子的唯一权威来源，但各省数字化程度参差（见 §7）。

### 3.3 合规约束

- 遵守 `robots.txt`，限速（每域名 ≥1s 间隔），非侵入式抓取，仅取公开页面；
- 合订本为正式出版物，**只抽取统计性字段**（院校、专业、科类、计划数、选科要求、学费），不做全文复制；
- 优先使用官方在线版；PDF 走「人工下载 + 本地脚本解析」；
- 所有产物标注 `source`（来源 URL）+ `fetchedAt`，可追溯可回滚。

## 4. 覆盖范围：TOP20 大省

口径为**夏季高考统考人数**（报名人数含高职单招/对口/专升本，会显著放大部分省份，如河南）。

| 批次 | 省份 | 说明 |
| --- | --- | --- |
| 批 1 试点 | 河南、广东 | 打通全链路，验证可复制性 |
| 批 2 复制 | 山东、四川、河北、湖南、安徽、江苏 | 规模大、数据格式较规整 |
| 批 3 收尾 | 湖北、江西、广西、贵州、浙江、云南、陕西、山西、福建、重庆、甘肃、辽宁 | 凑满 20 |

四川省因 `plan.sceea.cn` 有在线合订本，额外作为**招生计划通道的首个验证省**。

> 名单与位次依据公开报道的规模排序；实施时用各省考试院公布的统考人数最终确认，个别省份（如辽宁/黑龙江/内蒙古）位次可能互换。

## 5. 总体架构

```
configs/provinces/<prov>.toml   ← 省份配置（来源 URL、解析器、列映射）
        │
        ▼
fetchers/                        ← A/B 层：HTTP 抓取，落 raw/（HTML/PDF/XLS 原样存档）
        │
        ▼
parsers/                         ← 可插拔解析器：html_table | xls | pdf_text | manual
        │
        ▼
normalizers/                     ← 归一化到 6 张标准表，院校名/专业名规范化
        │
        ▼
staging/*.csv                    ← 中间层（人工可审阅，diff 友好）
        │
        ▼
validate/                        ← 三级校验（§8）
        │              ↘
        │                review_queue.csv   ← 需人工确认的异常行
        ▼
build/                           ← 生成产物
   ├── web:  src/data/generated/*.ts（或 .json）
   └── ios:  ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json
```

### 5.1 目录

```
data-pipeline/
  configs/provinces/*.toml
  configs/university_aliases.csv     # 院校名别名表（官方名 ←→ App 内名）
  pipeline/{fetch,parse,normalize,validate,build}.py
  pipeline/providers/{base,html_table,xls,pdf_text,manual}.py
  raw/<prov>/<year>/...              # 原始存档（不进 git 大文件，.gitignore）
  staging/*.csv
  review_queue.csv
  requirements.txt
```

技术栈：**Python 3.11 + pandas + requests + beautifulsoup4 + pdfplumber**（PDF 解析能力是选 Python 而非 Node 的决定性理由）。在 `package.json` 增加 `data:build` 脚本包装调用，保持「一条命令」体验。

### 5.2 增量与幂等

- `raw/` 按 `<prov>/<year>/<dataset>.<ext>` 存档，重复运行默认复用（加 `--force` 重抓）；
- 每次运行输出 `staging/` 全量覆盖 + `run_report.json`（抓取条数、校验通过率、复核条目数）；
- 产物生成前先跑校验门禁，复核队列非空且未 `--allow-pending` 时拒绝发布。

## 6. 数据契约（staging 六表）

所有字段与省份无关，省份差异在适配器中消化。

1. **rank_table.csv** — 一分一段表
   `prov_id, year, track, score, rank, cum_count`
   （`rank`=累计位次；`cum_count` 为该分段人数，缺失可空）

2. **batch_lines.csv** — 批次控制线
   `prov_id, year, track, special, undergrad, college, candidates, ug_plan`
   （对齐 `src/types.ts` 的 `YearLines`）

3. **admission.csv** — 院校投档线
   `prov_id, year, track, batch, uni_name, uni_raw, min_score, min_rank, plan, source, fetched_at`
   （对齐 `YearAdmission`；`official=true` 的来源）

4. **major_admission.csv** — 专业投档线（可选，二期主力）
   `prov_id, year, track, batch, uni_name, major_name, major_raw, min_score, min_rank, plan, subject_req`

5. **plan.csv** — 招生计划（合订本产物）
   `prov_id, year, track, batch, uni_name, major_name, plan, tuition, subject_req, source`

6. **university_meta.csv** — 院校主数据校准
   `uni_name, aliases, prov, city, level, kind, official_url`
   （`level` 对齐 `UniLevel`，`kind` 对齐 `UniKind`）

编码规范：`track` ∈ `phy|his`（3+3 省份统一归 `phy`）；`prov_id` 沿用 `src/data/provinces.ts` 现有 id；院校名统一去空格、全角括号、繁体。

## 7. 招生计划（合订本）三级策略

按「自动化程度」降序选择，每省在配置中声明所用级别：

| 级别 | 触发条件 | 做法 | 成本 |
| --- | --- | --- | --- |
| L1 在线版 | 省考试院提供在线可浏览的合订本（如四川 `plan.sceea.cn`） | 目录页 → 分页抓取 → HTML 表格解析 | 低，全自动 |
| L2 PDF 文字版 | 官方发布 PDF 合订本且为文字层（河南《招生考试之友》等） | 人工下载到 `raw/` → `pdfplumber` 抽取表格 → 规则清洗 | 中，半自动 |
| L3 扫描/纸质 | 仅扫描 PDF 或纸质本 | 人工录入关键院校/专业 → 填 `manual/` 模板 | 高，人工兜底 |

一期目标：批 1（河南 L2、广东 L1/L2）+ 四川 L1 跑通；其余省按可得性降级，允许 `plan.csv` 部分为空（缺失时沿用旧估算，不阻塞）。

## 8. 三级校验

**L1 结构校验（自动，阻断）**
- 必填字段非空；分数/位次为整数且落在合理域（分数 0–750，位次 >0 且 ≤ 该省统考人数×1.2）；
- 一分一段表：分数降序、位次单调不减、端点与批次线自洽（特殊线对应位次 / 总人数 ≈ 上线率历史区间）；
- 投档线：`min_score` 与 `min_rank` 方向一致（分越高位次越小），且与同年一分一段表插值出的位次偏差 ≤ 阈值；
- 唯一性：同 `(prov_id, year, track, uni_name)` 不重复。

**L2 交叉校验（自动，进复核队列）**
- 与 C 类开源数据集比对同 `(省, 年, 科类, 院校)` 的最低分：偏差 > 8 分（或位次相对偏差 > 15%）进队列；
- 与 eol.cn 聚合页比对批次线与一分一段关键分位点；
- 院校名无法匹配 `university_aliases.csv` → 进「新院校名」队列。

**L3 人工复核（半自动）**
- `review_queue.csv` 含 `reason`（规则名）、`observed`、`expected`、`source_url`；
- 人工在队列中填 `decision`（accept / fix:<值> / drop），重跑时自动应用并固化到 `configs/university_aliases.csv` 或 `overrides.csv`。

校验门禁：L1 必须全绿；L2/L3 未清空时，产物仅生成到 `staging/`，不写 `src/data/generated` 与 `bundle.json`（除非 `--allow-pending`）。

## 9. 交叉校验基线

- `pipeline/validate/crosscheck.py` 加载 C 类开源数据集（本地 SQLite/CSV，不联网），按 `(prov, year, track, uni_name)` 对齐；
- 匹配走 `university_aliases.csv` + 模糊匹配（去「大学/学院」后缀、编辑距离 ≤1）；
- 输出命中率与偏差分布到 `run_report.json`：命中率 < 60% 视为解析器失效，直接失败而非静默通过。

## 10. 年份滚动机制

- 管道按运行日期推导 `target_year`：`month >= 6 ? year : year - 1`（6 月后当年录取数据已/即将公布）；
- `history_years` = `target_year-3 .. target_year-1`，`current_year = target_year`；
- 产物写入 `src/data/generated/meta.ts` 导出 `CURRENT_YEAR` / `HISTORY_YEARS`；`src/data/provinces.ts` 改为从该文件 re-export（不删除现有常量符号，避免大范围改动）；
- 初始滚动结果：`current_year = 2026`，`history_years = [2023, 2024, 2025]`。

## 11. 与现有代码的衔接

| 位置 | 改动 |
| --- | --- |
| `src/lib/admission.ts` | 构建 `YearAdmission` 时：若官方数据存在该 `(uni, year, track)` 则直接采用 `score/rank/plan` 并置 `official=true`；否则回退现有确定性推导。概率与等效分计算逻辑不变 |
| `src/lib/ranktable.ts` | 有官方一分一段表时优先查表插值；无表时回退现估算 |
| `src/lib/dataset.ts` | 新增「官方数据集」加载路径，与用户手动导入的数据合并（官方为底，用户导入覆盖同键） |
| `src/data/provinces.ts` | `CURRENT_YEAR` / `HISTORY_YEARS` 改为引用 generated；`lines` 与 `candidates`/`ugPlan` 由 `batch_lines.csv` 生成覆盖 |
| `ZhiYuanTong/.../Dataset.swift` | 结构不变；`bundle.json` 由管道重新生成，`ColumnKey` 与 `parseCsv` 复用 |
| `package.json` | 新增 `data:build`（跑管道）、`data:validate`（仅校验） |

回退原则：**任何一步官方数据缺失，都必须优雅回退到现行为，不能让 App 出现空数据或崩溃。**

## 12. 验收标准

1. 河南、广东两省 `rank_table`、`batch_lines`、`admission` 三表覆盖 2023–2025 三年 × phy/his 两轨，L1 校验 100% 通过；
2. 交叉校验命中率 ≥ 60%，复核队列清空或逐条有 `decision`；
3. 新增第三个省（山东）时，仅新增配置文件 + 解析器（若格式已支持则零新代码），核心代码零改动——**这是可复制性的验收硬指标**；
4. `npm run build` 通过；iOS 侧 `bundle.json` 可被 `Dataset.swift` 正常解析，App 显示「已接入官方数据」；
5. 官方数据缺失场景（手工删掉某省文件）下 App 仍正常，回退到推算值。

## 13. 风险与开放问题

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 省站反爬 / 格式突变 | 抓取失败 | raw 存档 + 解析器契约测试（对每个省存一份 fixture）；失败降级 B 层 |
| 院校名不一致 | 匹配率低 | `university_aliases.csv` 持续积累；新名进复核队列 |
| 合订本版权 | 合规风险 | 只抽统计字段、优先官方在线版、不做全文复制 |
| 位次口径差异（含加分/艺体） | 数据污染 | 只取普通类；`track` 显式区分；异常值走 L1 域校验 |
| 开源基线数据本身有误 | 误判 | 交叉校验只用于「进复核」，不自动改写数据 |

开放问题（实施中确认）：

1. 广东省站投档线是否提供「最低位次」还是只有「最低排位区间」——影响 `min_rank` 精度；
2. 河南《招生考试之友》PDF 是否为文字层——决定 L2 是否可行；
3. 3+3 省份（山东、浙江）无 phy/his 分轨，统一归 `phy` 是否与用户认知冲突——需 UI 文案适配。
