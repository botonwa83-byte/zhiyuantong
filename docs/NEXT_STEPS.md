# 高考数据管道 · 下一步清单

> 更新于 2026-09-20（承接 2026-09-18 会话）。下次会话直接按本文件开工，无需重新调研。

> ⚠️ **2026-09-20 结构变更：Web 版已删除。**
> App 只有一套代码 —— 原生 SwiftUI 工程 `ZhiYuanTong/ZhiYuanTong.xcodeproj`。
> 根目录的 React/Vite/Capacitor 前端（`src/`、`index.html`、`vite.config.ts`、`capacitor.config.ts`、`public/`、`dist/`、`ios/`）已全部删除，避免「改了没反应」的误导。
> 数据集源文件（原 `src/data/*.ts`）迁到 **`ZhiYuanTong/Scripts/data/`**，仍是 `bundle.json` 的唯一来源：
> 改完数据执行 `bash ZhiYuanTong/Scripts/sync-data.sh`（或 `npm run data:ios`）重新生成 `ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json`，再在 Xcode 里重新编译。
> 根目录 `package.json` 只剩数据管道与数据导出脚本（依赖仅 `esbuild`），Web 依赖（`react`/`vite`/`@capacitor/*`）已随 `node_modules` 清理。

## 〇、断点（2026-09-20 收工，下次开工直接看这一节）

### 今天做完的：分批次志愿填报 · 三个阶段全部落地

| 阶段 | 内容 | 关键文件 |
| --- | --- | --- |
| 一 | 批次打通：投档线带 `batch`，按批次取数 | `ZhiYuanTong/ZhiYuanTong/Dataset.swift`（`BatchKind` 6 类归一化）、`Engine.swift` |
| 二 | 批次规则数据集：31 省志愿数/模式/志愿单位 | `ZhiYuanTong/Scripts/data/batches.ts` → `bundle.json.batchRules` → `Models.swift`（`BatchRuleDTO`）、`DataStore.batches(of:)`、`Dataset.swift`（`fillableBatches` / `tierQuota`） |
| 三 | App 按批次生成志愿表 | `Models.swift`（`VolunteerItem.batch`）、`Dataset.swift`（`buildBatchAdmissionIndex`）、`Engine.buildRecords(batch:)`、`AppState.swift`（`currentBatch` / `availableBatches` / `evals(for:)` / `selectBatch`）、`Recommend.swift`（`GenPrefs.batch`+`rule`）、`GenWizardView.swift`（第 0 步选批次）、`MyListView.swift`（批次切换/规则卡/提前批类别卡/征集提醒卡） |

设计细节与实测数据见 **`docs/BATCH_DESIGN.md` §六**。

**当前状态**：Xcode Debug 编译通过。命令行实测四个场景均正常（河南物理 550 → 本科批 48 个 / 专科批 48 个；辽宁物理 480 → 本科批 112 个；四川物理 520 → 提前批 A 段 3 个顺序 + 本科批 A 段 20 / B 段 45；河南物理 350 本科线下 → 只剩专科批次）。

### 明天第一件事（建议）：核对 28 个「未核对」批次的志愿数上限

App 里这些批次标了 ⚠️「志愿数上限待核对」。**错的上限比没有更危险**，考生照着填会填不进去或浪费志愿位。

- 优先级：河南、山东、河北、四川、广东、江苏（考生大省）→ 其余省份
- 数据源：各省教育考试院当年的志愿设置公告（不是网上的二手汇总）
- 改法：编辑 `ZhiYuanTong/Scripts/data/batches.ts` 对应批次的 `max`，确认后把 `verified` 改 `true` → `bash ZhiYuanTong/Scripts/sync-data.sh` → Xcode 重编译
- 顺带核对的字段：`sequential`（顺序/梯度志愿）、`groupUnit`（院校专业组 vs 专业+学校）、`majorsPerVolunteer`、`allowAdjust`、`note`

### 其余缺口（按优先级）

1. **征集志愿（补录批）无数据** —— App 只有提醒卡，考生要自己盯省考试院公告
2. **专项批（国家/高校/地方专项）没有资格字段** —— 现在按批次生成但不验证考生资格
3. **四川本科批 A/B 段、辽宁提前批 A/B 段共用同一批投档线** —— 源数据没分段，两个批次生成结果重复（已在 App 内提示，根治要改 `Dataset.batchOf` 的归一化规则）
4. **提前批的体检/政审/面试条件不在数据里** —— 只有类别不得兼报的提示
5. 老缺口：院校 `city`/`kind` 缺失（城市筛选退化）、海南 900 分制批次线待核对、只有 2025 一年真实录取数据（2023/2024 补跑三年线差）、清华北大等部分顶尖院校在源数据里没有投档线

### 续工常用命令

```bash
# 改完 batches.ts 或任何 data/*.ts 后重新生成 bundle.json
bash ZhiYuanTong/Scripts/sync-data.sh

# 编译验证
cd ZhiYuanTong && xcodebuild -project ZhiYuanTong.xcodeproj -scheme ZhiYuanTong \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
# 报 all-product-headers.yaml 写不了 → rm -rf ~/Library/Developer/Xcode/DerivedData/ZhiYuanTong-*

# 算法冒烟（不依赖 Xcode）：先 cp Resources/Data/bundle.json /tmp/bundle.json，再 swiftc 编
# Dataset.swift Models.swift RNG.swift DataStore.swift Engine.swift Employment.swift Recommend.swift + 临时 main.swift
```

## 一、当前状态

工作目录：`data-pipeline/`（虚拟环境 `.venv`，命令前缀 `cd data-pipeline && .venv/bin/python -m ...`）

| 产物 / 模块 | 结果 |
| --- | --- |
| `staging/rank_table.csv` | **2025 年 28 省，26195 行**（3+3 省份只有「综合」一轨，见 §3.11） |
| `staging/admission.csv` | **2025 年 29 省，67189 行**（含专业组/选科/位次，位次已按一分一段重算） |
| `staging/university_meta.csv` | **2700 所院校**（按规范名聚合，跨省招生代码不同，见 §3.11） |
| `dist/app_import/` | **57 个文件**（28 份一分一段 + 29 份投档线），App 可直接导入 |
| `dist/universities_full.csv` | 2700 所，App 可直接导入（`uni_code,name,prov,city,level,kind,nature`） |
| `providers/prov_pdf.py` | **新增**：考试院一分一段 PDF 解析器（河南历史类 PDF 仍解析 0 行，待核对版式） |
| `configs/provinces/*.toml` | 31 省配置（新疆/西藏改文理分科、海南满分 900、山西与河南专业线源停用） |
| 校验 | **阻断 0 / 警告 6**（29 省全量统一校验一次） |
| 单测 | **112 passed**（`python -m pytest tests -q`） |

已实现模块：`config` `contract` `providers/{base,hf_csv,html_table,manual,xls,prov_pdf}` `parse` `normalize` `validate` `staging` `years` `derive` `build` `run`。

## 二、已确认的关键决策（不要再问）

1. **数据获取：只读本地 + 人工下载**。HF 直连不通、镜像站 robots.txt 为 `Disallow: /`，故 `hf_csv` / `prov_pdf` 只校验本地副本，缺失抛 `MissingArchive` 并在报告中标记 `missing`（不算失败）。下载清单用 `--all --year 2025 --list`。
2. **院校库扩到数据集全量**。合并规则：App 内置 104 所手工标注优先，官方数据只补空位。
3. **历史类一分一段表走各省教育考试院 PDF**（数据集只有物理类），由 `prov_pdf` 承担。
4. **省份范围以 App 为准**：`ZhiYuanTong/Scripts/data/provinces.ts`（13 省）+ `provincesExtra.ts`（18 省）= 31 省，含 3+3 六省（山东/浙江/北京/天津/上海/海南）。管道配置已按这 31 省铺齐，"19/20 省"的旧说法作废。

## 三、待办清单（按优先级）

### 1. 人工下载（阻塞项，需要用户操作）
- [ ] 河南 2025 四个 CSV 的人类浏览器副本覆盖 `raw/henan/2025/`（现有文件是 curl 取的，来源不干净）：`score-range`、`school-admission`、`major-admission`、`enrollment-plan`
- [ ] 河南 2025 **历史类**一分一段 PDF → `raw/henan/2025/rank_table_his.pdf`（发布页：`https://www.haeea.cn/a/202506/43550_7465740d.shtml`）
- [ ] 用 `python -m pipeline.run --all --year 2025 --list` 导出 31 省清单，浏览器逐个下载
  - `raw/<省id>/<年>/<kind>_<dataset>.csv`；数据集实际目录名可能与 App 的 id 拼写不同（尤其 `neimenggu` / `xizang` / `shaanxi`），**第一次下载时对着 HF 数据集页面核对一遍 URL 是否 404**，不一致的话改对应 toml 里 `url_template` 的目录段即可
- [ ] 下载齐后：`python -m pipeline.run --all --year 2023 --year 2024 --year 2025`

### 2. `prov_pdf` 落地验证（本轮已完成代码实现，缺真实数据）
- [x] `pipeline/providers/prov_pdf.py`：表格优先 + 无框线/多栏退回按坐标聚词；支持表头匹配、显式列号、自动步长、rank 派生、分数域校验、同分去重
- [x] `SourceSpec.url_overrides`：考试院 PDF 直链含随机 hash，无法用 `{year}` 模板推导，逐年登记
- [x] `run.py` 支持 `options.track`（单轨来源不再被默认成物理类）
- [ ] **拿到河南历史类 PDF 后跑一次，校对段首/段尾总人数与官方公布累计是否一致**，再推广各省
- [ ] 物理类也建议同步走官方 PDF，避免与数据集口径不一致（对照現有 225 行）
- [ ] 逐省版式差异（四栏/两栏、有无"本段人数"列）只需改 toml 的 `columns` / `col_stride` / `*_col`，不需要改代码

### 3. App 端集成（**React 版已于 2026-09-20 删除，以下为历史记录，仅作算法/数据说明保留**）
- [x] `src/types.ts` 的 `UniversitySeed`：**除 `name` 外全部改可选**（新增 `uniCode` / `nature` / `imported`）
- [x] 缺字段统一降级：新增 `src/lib/uni.ts`（`NO_DATA` / `uniMetaLine` / `uniLevelOf` / `uniKindOf` / `listOf` / `pctLabel` / `yuanLabel` / `UNI_LEVELS` / `UNI_KINDS`），展示层显示「暂无官方数据」，模型层用同层次同类型保守推算，**不编造数值**
- [x] `base/baseHis` 优先官方投档线反推：`src/lib/admission.ts` 的 `baseFromOfficial` 取近三年（min_score − 当年特殊类型线）中位数；无官方数据才回退人工 base，最后才用 `LEVEL_BASE` 同层次兜底
- [x] 院校库导入入口：`src/lib/dataset.ts` 新增 `parseUniversityCsv` / `importUniversityCsv` / `TEMPLATE_UNIVERSITY`；`DataImport.tsx` 新增「院校库」tab
- [x] `src/data/universities.ts`：`universitySeeds` 由常量改为**函数**（内置条目 + 官方导入按名合并，内置手工标注优先），`setImportedUniversities` 由 `App.tsx` 每次渲染同步；`cityHeatOf` 支持城市缺省
- [x] 实测：`data-pipeline/dist/universities_full.csv`（608 行 → 去重后 606 所）导入后院校库 **791 所**，`buildRecords` 约 3ms、`allForecasts` 约 52ms，无 NaN / Infinity
- [ ] 性能（**待办仍在原生端**）：院校规模继续涨（2000+）时 `ExploreView.swift` 列表需 `LazyVStack` / 分页；产物考虑按省分包 + gzip
- [ ] 院校筛选面板（`ZhiYuanTong/ZhiYuanTong/ExploreView.swift`）的城市选项写死为 18 个热门城市：**院校库扩容后需改为从当前院校库动态收集**，否则官方导入院校所在的非热门城市无法筛选

### 3.5 智能生成志愿表（软件核心功能，本轮完成）
- [x] 新增 `src/components/GenSheet.tsx` 四步向导：意向城市 → 意向专业（学科门类 + 热门专业）→ 服从调剂与冲稳保策略（含优先本省）→ 确认（实时预览冲/稳/保数量、体检提示、前 6 个志愿预览）
- [x] `src/lib/recommend.ts` 用 `genVolunteers(evals, prefs, ds)` 取代原 `autoFill`：先allocate配额再按「城市 30 / 专业 12×命中数 / 本省 10 / 就业景气 / 热度」排序，配额下沉与补齐（高分考生全为「保」时补满 42 个），每组内按等效分降序，**已验证无重复、无梯度倒挂、标签与概率一致**
- [x] 偏好写入档案（`StudentProfile` 新增 `strategy` / `preferProvince` / `hotMajors`，`storage.ts` 的 `normalize` 补默认值），下次打开向导自动带出
- [x] 入口：首页新增醒目 CTA 卡片 + 冲稳保卡片按钮；志愿表页「一键智能填充」同样打开向导；生成后 `ctx.go('list')` 跳转，`App.tsx` 在 `screen` 变化时 `window.scrollTo(0)`（否则停在原滚动位置，看起来像「没反应」）
- [x] 每个志愿带 `note`（专业匹配 / 意向城市 / 本省院校），`MyList.tsx` 展示生成理由
- [x] 实测：henan 物理类 420-720 分共 7 档 + 8 组偏好组合，生成耗时 <2ms，保底不足 / 不服从调剂 / 无可冲刺院校均有提示，挑不出 ≥15% 院校时不清空已有志愿表

### 3.6 原生 SwiftUI 版本（ZhiYuanTong/）—— App 的唯一实现
> **重要**：手机上跑的是 `ZhiYuanTong/ZhiYuanTong.xcodeproj`（原生 SwiftUI 实现）。原 `src/` React 版已删除，不存在"两套独立代码"。
> 改 UI / 算法一律改 `ZhiYuanTong/ZhiYuanTong/*.swift`；改数据集改 `ZhiYuanTong/Scripts/data/*.ts` 后跑 `bash ZhiYuanTong/Scripts/sync-data.sh`，再在 Xcode 重新编译。
- [x] 2026-09-20 同步§3.5：`ZhiYuanTong/ZhiYuanTong/GenWizardView.swift` 四步向导（意向城市 → 意向专业 → 服从调剂与梯度 → 确认预览）
- [x] `Recommend.swift` 用 `genVolunteers(list, prefs:, ds:)` 取代 `autoFill`，逻辑与 TS 版一致（配额 → 偏好排序 → 组内等效分降序 → 名额下沉/补齐）
- [x] `Models.swift` 加 `GenStrategy` 与 `strategy` / `preferProvince` / `hotMajors`，并为 `StudentProfile` 自定义 `Decodable`（老存档缺这三个键也能读出来，不会丢档）
- [x] `AppState` 新增 `AppTab` + `@Published var tab`，`generateVolunteers(prefs:)` 写回偏好后 `tab = .list` 跳转；`RootView` 的 `TabView` 绑定 selection + tag
- [x] 首页新增「智能生成志愿表」CTA 卡片；志愿表页菜单「一键智能填充」改为打开同一向导；志愿条目展示 `note`
- [x] 新文件已手工登记进 `project.pbxproj`（iOS + macOS 两个 target 的 PBXBuildFile / PBXFileReference / PBXGroup / PBXSourcesBuildPhase）。**不要用 xcodegen 重新生成**，`project.pbxproj` 里有 DEVELOPMENT_TEAM = Z7F8BY55DS 等签名设置会丢失
- [x] 真机/模拟器自检：henan 物理类 420/480/520/560/600/640/680 七档无重复、组内层次顺序正确、高分档自动补满 42 个；偏好组合（杭州/南京 + 工学 + 计科）命中 190/286、37 个志愿带理由
- [x] 2026-09-20 定稿：**确定以原生版为准**。React 版整目录删除，数据集迁到 `ZhiYuanTong/Scripts/data/`，原生 App 与数据集同源，不再有双份实现
- [x] 2026-09-20 修 `ZhiYuanTong/Scripts/export-data.ts`：`universitySeeds` 改成函数后导出脚本仍按常量调用（`.map` 会崩），已改为 `universitySeeds()`；重新生成 `bundle.json`，**把 6 所陕西高校 `shanxi`→`shaanxi` 的修正同步到了原生端**（此前只改了 TS，bundle 未刷新）
- [ ] `XcodeGen` 的 `project.yml` 与 `project.pbxproj` 已不同步（新文件是手工登记的）：以 `ZhiYuanTong.xcodeproj` 为准，`project.yml` 仅供参考，不要反向生成

### 3.7 科类口径（2026-09-20 修正，详见 `docs/superpowers/plans/2026-09-20-track-mode-and-major-data.md`）
> 用户提出「高考没有物理类/历史类之分，河南好像是 3+2」，核实后结论：**河南是 3+1+2（不是 3+2）**，官方一分一段表、批次线、投档线**按首选科目分物理类/历史类分别公布**（河南教育考试院 2025-06-25 发布），所以 `phy/his` 建模本身正确。但另外两处口径确实错了，已修。
- [x] 3+3 六省（山东、浙江、北京、天津、上海、海南）**不分科类**，只有一个综合位次：建档页 / 档案页科类选择器对这六省隐藏，首页显示「综合」（原来是「物理类/历史类」二选一，误导）
- [x] 新疆、西藏：**2024 秋高一才启动改革、2027 年首考**，2022–2026 届仍是文理分科 → 新增 `ExamMode.old = "文理分科"`，界面显示「理科 / 文科」；`candidatesOf` 老高考按理科 68% / 文科 32% 拆分（3+1+2 仍为 62% / 38%）
- [x] 新疆 2025 批次线修正：理科 421 / 280 / 140，文科 451 / 330 / 140（原 392/265 与 427/306 与官方不符）
- [x] 科类文案统一入口 `trackLabel(track, mode)`（`Models.swift`），UI 不再直接写死「物理类」；`ExamMode` 自定义解码，未知取值回落 3+1+2，不会因脏数据整份解码失败
- [x] `export-data.ts` 加导出前校验：模式白名单 + 3+3 省份两轨必须一致，数据写错直接在导出阶段报错
- [ ] 待人工验收（模拟器/真机）：山东 → 无科类选择器且显示「综合」；新疆 → 「理科/文科」；河南 → 「物理类/历史类」；老账号登录不丢档
- [ ] 后续两大项已拆成独立计划（同一 plan 文件末尾）：**Plan B 专业级录取数据 `major_admission`**（含 3+1+2 选科要求硬过滤）、**Plan C 外部数据接入**（掌上高考仅作人工核对/人工导出，不爬其非公开接口）

### 3.8 专业级录取数据（2026-09-20 完成数据链，App 端已可导入展示）
- [x] 契约已有 `major_admission`（`data-pipeline/pipeline/contract.py`）；`providers/base.py` 的 `local_only` 加入 `manual`，人工整理 CSV 走 `raw/<省>/<年>/` 本地路径，不再尝试联网下载
- [x] 河南配置新增 `[[sources]] kind = "major_admission" parser = "manual"`（`configs/provinces/henan.toml`），本地文件 `raw/henan/{year}/major_admission_major.csv`
- [x] CSV 模板 `data-pipeline/templates/major_admission_template.csv`：`院校名称,专业名称,录取批次,科类,最低分,最低位次,计划数,选科要求`
- [x] 新增测试 `data-pipeline/tests/test_major_admission.py`（manual 本地路径、归一后列与合同一致、重复主键被判阻断）；全量 `pytest` 90 通过
- [x] App：`OfficialMajorAdmission` + `OfficialDataset.majorAdmissions`（自定义 Codable，**老存档无该键时按空数组处理，不丢档**）、`findMajorAdmissions`、`importMajorAdmissionCsv`、导入页新增「专业录取线」类型、院校详情新增「专业录取线」卡片（带选科要求标签）
- [x] 选科基础：`Models.swift` 新增 `GAOKAO_SUBJECTS`，`StudentProfile.subjects`（已存在但此前无人填充）；专业行有 `requiredSubjects` 与 `meets(_:)`，考生填了选科会标「选科不符」
- [x] 档案页新增「选考科目」多选（3+1+2 首选科目由科类自动补全；3+3 六门任选；老高考不显示），档案概览展示已选科目
- [x] `Recommend.genVolunteers` 选科**硬过滤**：只对已导入专业录取线的院校生效，该校已录专业无一符合选科 → 剔除并在 warnings 里说明；无专业数据的院校不参与过滤（避免误杀）
- [x] 专业级概率（2026-09-20 完成）：`Engine` 新增 `MajorEval` / `equivScore(ofMajor:)` / `evaluateMajors(_:)`——专业线按「线差不变」折算今年等效分，概率 = 线差法（σ≈7 分）为主，有专业位次时位次法加权 35%；`AppState.majorEvals(_:)` 按档案实时算
- [x] 展示：院校详情「专业录取线」卡片改为概率排序 + 等效分 + 冲稳保标签 + 可报专业数；志愿表每行标注「可报专业 N/M 个 · 稳妥 K 个 · 最稳 XX 65%」；生成向导对「符合选科专业不足 3 个」的院校给出警告
- [x] 志愿条目展开「可报专业清单」（2026-09-20）：点开显示该校专业级概率（等效分/分差/计划/冲稳保/选科要求，限 12 条）
- [x] 专业级信息进入生成结果：推荐理由带「可报专业 N 个（稳妥 K 个）」；院校线够得上但可报专业都够不着的「假稳」志愿会给出警告
- [ ] 待做（下一轮）：31 省批量首跑（先跑通 `--all --year 2025` 的下载清单与缺失统计）

### 3.9 分省产物包（2026-09-20 完成，App 可直接导入）
- [x] `pipeline/build.py` 新增 `build_app_imports()`：从 staging 导出 `dist/app_import/{prov}_rank.csv`、`{prov}_admission.csv`、`{prov}_major.csv`，表头与 App 导入页模板一致
- [x] 投档线按「省份+年份+科类+院校」聚合：多个专业组取**最低**的那条做院校线，计划数**求和**（河南 2025：1687 行 → 1055 所/组）
- [x] 科类写成各省口径中文名（3+1+2 → 物理类/历史类，3+3 → 综合，文理分科 → 理科/文科），省份写中文名（App `normalizeProvince` 按名称匹配）
- [x] CLI：`python -m pipeline.build --prov henan [--only app-import|universities]`；新增 `tests/test_build_app_imports.py`（4 项），全量 `pytest` 94 通过
- [x] `dist/` 加入 `.gitignore`（生成物，可随时重跑）

### 3.10 位次口径校正（2026-09-20 完成，512 条复核队列已定位根因）
- [x] 根因：Gaokao-Compass 的 `school-admission` 里 `min_rank` **不是最低分位次**，河南 2025 物理类 706 条可比行**全部**系统性偏小（中位仅期望值的 0.677 倍）——北大医学部 674 分标 82 位，而 82 位在河南对应 702 分，疑似填的是最高分位次。错误位次比没有位次更危险：App 的位次法概率会据此把院校判成「几乎不可能」
- [x] 管道：`pipeline/derive.py` 新增 `rank_lookup` / `interpolated_rank` / `reconcile_min_rank`，`run.py` 落库前对 admission、major_admission 校正；河南 2025 结果：511 条按一分一段表**重算**（674 分 82 → 1917）、968 条（历史类 + 表外分数）置空，警告 512 → 1
- [x] 两阶段判定：① 逐行比对偏差 > 5% 即重算（refill=False 可改为置空）；② 某来源可比行过半不符 → 判该来源口径整体不可用，**包括无法逐行比对的科类**（河南历史类缺一分一段表）位次一并置空，避免同源错误数据留库
- [x] App：`Dataset.swift` 新增 `interpolatedRank` / `reconcileAdmissionRanks` / `reconcileMajorRanks`，导入投档线/专业线时若位次与已导入的一分一段表偏差 > 40% 即按表重算；**先导入投档线、后导入一分一段表**的情况会在导入一分一段表时回溯重算
- [x] 新增 `tests/test_reconcile_rank.py`（7 项），全量 `pytest` 101 通过

### 3.11 31 省批量首跑（2026-09-20 完成，阻断 0 / 警告 6）

跑法：`raw/` 备齐 64 份省级 CSV（本地副本，管道不自动下载）→ `python -m pipeline.run --all --year 2025` → `python -m pipeline.build --all`。

覆盖情况（2025）：

| 类别 | 省份 |
| --- | --- |
| 一分一段 + 投档线齐全 | 安徽 北京 重庆 福建 甘肃 广东 广西 贵州 海南 河北 黑龙江 河南 湖北 湖南 江苏 江西 吉林 辽宁 内蒙古 宁夏 陕西 山东 上海 四川 天津 新疆 云南 浙江（28 省） |
| 只有投档线 | 西藏（一分一段源 missing） |
| 无数据（源 404） | 青海 |
| 已停用 | 山西（源数据科类缺失 + 分数是折算值）、河南专业线（源是反爬 HTML 页面） |

本轮修掉的真 bug（按踩坑顺序）：

1. **批跑只剩最后一省**：`write_table` 全量覆盖。新增 `_merge_existing()`：按 `prov_id + year` 替换本次省份的行；`university_meta` 没有省年份，改为按院校聚合。
2. **院校名含截断 UTF-8 字节**：写出的 staging 行从 10 列变 19 列，下一轮回读直接 ParserError 崩掉。新增 `providers/base.clean_text()`（去 U+FFFD 与控制字符）+ `read_csv(encoding_errors="replace", on_bad_lines="warn")`。
3. **山西科类缺失**：源里 `category` 全空，物理/历史两块数据拼在同一份 CSV（600 分同时出现累计 10452 与 1918 两条），且分数是折算值（442.152094087）。**已按省停用**——这种数据进 App 会让历史类考生拿到物理类位次，比没有数据更危险。
4. **海南标准分**：满分 900，硬编码 750 会把全省判成超范围。配置新增 `max_score`（默认 750），validate 按省取上限。
5. **新疆/西藏仍是文理分科**：数据集写「理科/文科」，`track_filter` 按「物理类/历史类」过滤会把行全滤掉（表现是「解析出 0 行」）。已改 filter。
6. **脏行入库**：一分一段有 4 行只有分数没位次、投档线 167 行没有最低分。新增 `_drop_incomplete()` 按表的关键字段丢弃（`rank_table` 要 score+rank，`admission` 要 min_score）。
7. **同一分数两份一分一段表**：去重时保留累计位次更大的那份（小表只覆盖一段批次，用它换算会系统性偏乐观）。
8. **院校主数据膨胀到 23723 条**：同一所大学在各省招生代码不同（山东大学 44 个代码），按 `(uni_code, uni_name)` 去重无效。改为 `derive.aggregate_university_meta()` 按规范化名称聚合 → 2700 所。注意 **`uni_code` 是各省招生代码，不是教育部国标代码**，别当全局主键用。
9. **合并键类型不一致**：内存里是 `pd.NA`（`<NA>`），落盘读回是 `NaN`（`nan`），还有 `1244` / `1244.0` 三种写法，`_key_text()` 统一归一化后才能去重。
10. **导出没按省过滤**：全量 staging 下每省的 `{prov}_rank.csv` 都写成了全国全量。`_read_staging(kind, staging, prov_id)` 加省份过滤；重跑前先 `rm -rf dist/app_import`（某省缺表时旧文件不会被覆盖）。

位次校正结果：**28 省全部命中**（不只是河南），median 比值 0.71–0.85 —— Gaokao-Compass 的 `min_rank` 整体口径有问题，各省约 3.7 万条已按一分一段表重算。江苏/天津/内蒙古另有少量 `dropped`（表中查不到对应分数，位置空）。

- [ ] 待办（数据缺口）：`dist/universities_full.csv` 有 2700 所院校，但 **90 所缺属地、`city` 全空**（数据集 `school-admission` 只有 `school_province`，没有 city），App 的城市筛选对官方导入院校会失效 → 需另找院校城市来源（教育部院校名录 / 阳光高考人工导出），或继续走"名称匹配 + 空值降级"；**不要用院校名前缀猜省份**（"中国音乐学院"这类会猜错）
- [ ] 待办：青海补源、西藏补一分一段、山西换源或人工拆科类、河南专业线按模板人工录入
- [x] **分批次志愿填报 · 阶段一（批次打通）**：调查与设计见 `docs/BATCH_DESIGN.md`。投档线导出保留批次、聚合键含批次，App 侧 `BatchKind` 归一化与主批次院校线
- [x] **分批次志愿填报 · 阶段二（批次规则数据集）**：`Scripts/data/batches.ts` 31 省规则（批次顺序 / 志愿数上限 5~112 / 平行或顺序 / 院校专业组或专业+学校 / 提前批类别 / 征集提示）→ `bundle.json.batchRules` → Swift `BatchRuleDTO`、`DataStore.batches(of:)`、`fillableBatches`、`tierQuota`
- [x] **分批次志愿填报 · 阶段三（App 按批次生成志愿表）**：`VolunteerItem.batch` + `buildBatchAdmissionIndex`（只收录该批次有投档线的院校）+ 向导第 0 步选批次 + 志愿表批次切换/规则卡/提前批类别卡/征集提醒卡 + 冲稳保按批次上限分配（顺序志愿不冲）。实测河南 48、辽宁 112、四川 A/B 段分段生成均正常
- [ ] 待办（分批次剩余缺口）：征集志愿（补录批）无数据、专项批资格字段、四川本科批 A/B 段与辽宁提前批 A/B 段共用投档线（志愿会重复，已提示）、**28 个批次的志愿数上限需逐条核对官方文件**（考生大省优先）、提前批体检政审条件
- [ ] 待办：`prov_pdf` 用真实 PDF 验证（河南历史类 PDF 仍解析 0 行，多半是版式/表头不匹配）
- [ ] 待办：2023 / 2024 年同样跑一遍（`--all --year 2023 --year 2024`），凑齐三年线差

### 4. 产物与打包（Task 8-10）
- [x] 多省批量：31 省 2025 首跑完成（见 §3.11）
- [ ] 产物分发方式：目前产物 CSV 需手工传进手机再在 App 里导入，后续可考虑打包成 `.zyt` 数据集文件或直接在 App 内置按省下载

## 四、已知坑（避免重复踩）

- **列名抢占**：`prov` 会被 `prov_id` 的别名列表抢走（"province" 列先命中），院校所在地必须用 `uni_prov`。同理新增列要避开 `province`/`prov` 等通用别名。
- **normalize 丢弃非契约列**：想保留列必须先加进 `contract.py` 的 `TableSpec.columns`。
- **同省跨年派生院校会重复**：`run.py` 已按 `uni_code+uni_name` 去重，新增派生逻辑时同样要去重，否则触发唯一键阻断。
- **新高考模式**：河南 mode 为 `3+1+2`，track 只有 phy/his 两轨，不要出现"文理"旧口径。
- **数据集字段边界**：`school-admission` 有 `university_code`、`school_province`、`school_nature`、`is_985`、`is_211`；**没有 city、没有 kind（综合/理工）**，这两项只能留空或另找来源。
- `level` 推导规则：is_985=1→985，is_211=1→211，nature=民办→民办/独立学院，否则普通本科（`pipeline/derive.py`）。"顶尖985/双一流/省重点" 数据无法推导，只能来自 App 内置标注。
- **科类口径（2026-09-20）**：3+3 六省（山东/浙江/北京/天津/上海/海南）**不分科类**，不要给物理/历史两套线（`export-data.ts` 导出时会报错）；文理分科省份的数据行里 **phy 列是理科、his 列是文科**，别按物理/历史理解；新疆/西藏 2027 年才首考新高考，2026 及以前的届次按文理分科处理，2027 年起才切 3+1+2。科类文案一律走 `trackLabel(_:_:)`。
- **掌上高考（m.gaokao.cn）只能人工用**：数据到专业级很全，但接口是抓包得到的非公开 API、有反爬与服务条款约束，且是二次聚合数据。**只做人工浏览器核对 / 人工导出 CSV 进 `manual` provider，不写爬虫**；一手源优先（各省教育考试院一分一段 PDF、投档线，阳光高考 `gaokao.chsi.com.cn`）。
- **3+3 省份不要加 `track_filter`**：数据集只有一个"综合"轨，`track_filter = ["物理类","历史类"]` 会把行全滤掉导致「解析出 0 行」报错。3+3 省份的 toml 里已改为注释说明。
- **聚合数据源的 min_rank 不可信（2026-09-20）**：Gaokao-Compass `school-admission` 的 `min_rank` 疑似「最高分位次」，河南 2025 全部系统性偏小（中位 0.677 倍）。管道 `reconcile_min_rank` 已自动按一分一段表重算/置空，App 导入时也会重算。**新增数据源时先跑一遍看 run_report 里的 `rank_reconcile`**，出现 `unreliable_sources` 就说明该源位次不能用。
- **多省批量跑的告警计数**：`staging/` 是共享的，各省报告里若各自跑 `validate_staging` 会把同一批告警重复计 N 次；现已改成跑完全部省份统一校验一次，`run_report.json` 结构为 `{years, provinces[], blocking_issues, warning_issues, issues}`。
- **App 院校属地 id**：`ZhiYuanTong/Scripts/data/universities.ts` 里 6 所陕西高校（西安交大、西工大、西北农林、西电、陕师大、西安理工）曾误写 `shanxi`（山西），已修正为 `shaanxi`。新增院校数据时注意 `shanxi`(山西) / `shaanxi`(陕西) 的拼写。
- **多省批跑必须带省份过滤（2026-09-20）**：staging 是 31 省共享的，任何"写整表"（`write_table`）或"读整表"（`_read_staging`）的地方都要带 `prov_id`——写的时候用 `_merge_existing` 按 `prov_id+year` 替换，读的时候按 `prov_id` 过滤。否则会静默出错：只剩最后一省数据，或每省产物都写成全国全量（西藏 rank 导出 26195 行就是这么来的）。这是批跑最容易踩的一类 bug。
- **源不可信就在配置里停用（2026-09-20）**：`[[sources]]` 加 `disabled = true` + `note`，跑批会标记 `disabled` 并跳过，比留着脏数据或删掉配置更可控。已停用：山西（科类缺失 + 分数是折算值）、河南专业线（源是反爬 HTML 页面）。
- **人工副本可能是 HTML 反爬页**：`manual` provider 原先会把 HTML 当 CSV 解析出垃圾行（河南专业线解析出 9 行），现已加 HTML 头检测直接报错。同理 `hf_csv` 读回 staging 时带 `encoding_errors="replace"`，写入前走 `clean_text()` 去掉 U+FFFD 与控制字符——院校名里含截断 UTF-8 字节会让 CSV 列数错乱，下一轮回读直接 ParserError 崩掉。
- **院校 `uni_code` 不是国标代码（2026-09-20）**：数据集里的是各省招生代码，同一所大学在不同省代码不同（山东大学 44 个代码），按 `(uni_code, uni_name)` 去重无效，院校主数据会膨胀到 23723 条。已改为按规范化名称聚合（`derive.aggregate_university_meta`）→ 2700 所。**别把 `uni_code` 当全局主键**。
- **合并键类型不一致**：内存里是 `pd.NA`（`<NA>`），落盘读回是 `NaN`（`nan`），还有 `1244` / `1244.0` 三种写法，去重/合并前先用 `_key_text()` 归一化。
- **海南满分 900（2026-09-20）**：不是所有省都 750。配置新增 `max_score`（默认 750），validate 按省取上限，否则海南全省被判"分数超范围"。

## 五、常用命令

```bash
cd data-pipeline
.venv/bin/python -m pipeline.run --prov henan --year 2025            # 跑单省
.venv/bin/python -m pipeline.run --all --year 2025 --list            # 导出下载清单（--prov 不再必填）
.venv/bin/python -m pipeline.run --all --year 2025                   # 全量跑
.venv/bin/python -m pipeline.run --all --year 2025                   # 全量跑：29 省，约 40s
.venv/bin/python -m pipeline.build --all                              # 全部省份产物（dist/app_import/{prov}_{rank,admission}.csv）
.venv/bin/python -m pipeline.build                                    # 院校库 + App 可导入 CSV（默认省份）
.venv/bin/python -m pipeline.build --prov henan --only app-import     # 只导出一分一段/投档线/专业录取线
.venv/bin/python -m pytest tests -q                                   # 单测（113 passed）
cat staging/run_report.json                                           # 运行报告（含 missing/failed 来源）

# 管道产物 -> App 内置数据（sync-data.sh 会自动拷贝 dist 到 App 资源）
bash ZhiYuanTong/Scripts/sync-data.sh   # 生成 bundle.json（含院校库并入）+ 同步 official/*.csv

cd ZhiYuanTong
xcodebuild -project ZhiYuanTong.xcodeproj -scheme ZhiYuanTong -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## 五·五、App 内置官方数据（2026-09-20）

**定位：数据随 App 打包，按考生高考省份自动匹配；用户不上传数据、不校准分数线。**

- 资源：`ZhiYuanTong/ZhiYuanTong/Resources/Data/official/{prov}_{rank,admission}.csv`（29 省，57 个文件，3.2 MB）+ `universities.csv`（管道院校主数据 2700 所）
- 工程引用：`official` 目录在 pbxproj 里是 **folder reference**，新增省份拷贝文件即可，不用改工程
- 装载：`OfficialData.swift` 按 `profile.provId` 读 CSV → 复用 `importRankCsv/importAdmissionCsv`（位次按一分一段表复核）→ 缓存；`AppState.recompute()` 每次自动装载
- 数据集**不再存 UserDefaults**（旧存档在 init 里清掉）；「导入 / 管理官方数据」与「批次线校准」入口已删除，`DataImportView.swift` 已删除；老版本留下的 `linesOverride` 在「我的」页提供一次性清除入口
- 年份：`HISTORY_YEARS = [2023, 2024, 2025]`、`CURRENT_YEAR = 2025`（内置录取数据就是 2025 年）。**Engine 规则：某校若有内置官方数据的年份，只用官方年份算 avgDiff/avgRank，模型推算值不参与平均**（否则 2023/2024 无数据时假值会稀释真实线）
- 院校库：346 → 2703 所。新增院校的 `base` 由该校在已内置省份的投档线反推「分数 − 特殊类型线」的中位数；`city`/`kind`/`strengths` 数据集没有，留空；就业字段按办学层次取中位数（UI 标为模型估算）
- 性能：投档线查找加了 `admissionIndex`（prov|track|year|院校名 → 记录），院校扩到 2700 所后不至于逐年逐校线性扫描

待办 / 已知缺口：
- [ ] 院校 `city` 全空、`kind` 为空 → ExploreView 按城市 / 院校类型筛选时只剩内置那 346 所，需另找院校城市来源（教育部院校名录）
- [ ] 海南为 900 分制标准分，`provincesExtra.ts` 里仍是 750 制近似值（special 475），需按真实标准分核对；`universitiesFromOfficial.ts` 已跳过海南样本避免线差失真
- [ ] 只有 2025 一年真实录取数据（2023 / 2024 待补），趋势曲线与「三年线差」仍是模型值 + 一年真值

## 六、本轮改动清单（便于 review）

### 本轮（2026-09-20 · App 内置官方数据，去掉导入与校准）

- 新增 `ZhiYuanTong/OfficialData.swift`：按考生省份自动装载内置 CSV（含缓存与覆盖统计）
- `AppState.swift`：数据集不再持久化到 UserDefaults（旧存档清除）、`recompute()` 自动装载、删除 `importXxx / clearDataset / stats / hasOfficialData`，新增 `coverage`
- `MeView.swift`：数据接入卡 → 数据覆盖卡；删除导入与批次线校准入口、`CalibrateSheet`
- 删除 `DataImportView.swift`（pbxproj 同步清理）；`HomeView` / `UniDetailView` / `MyListView` / `Recommend` 的「导入」文案改为「内置」
- `Engine.swift` + `Models.swift`：有内置官方数据的年份只用官方年份；`Province.linesUpTo` 支持批次线按最近年份回退；新增 `admissionIndex`
- `Scripts/export-data.ts` + `Scripts/data/universitiesFromOfficial.ts`：管道院校主数据并入院校库（346 → 2703 所），base 由投档线反推
- `Scripts/data/provinces.ts`：`HISTORY_YEARS` 改 `[2023, 2024, 2025]`；`sync-data.sh` 同步 dist 产物到 App 资源

### 上一轮（2026-09-20 · 31 省批量首跑）

- `pipeline/run.py`：新增 `_merge_existing()`（按 `prov_id+year` 替换，修"批跑只剩最后一省"）、`_drop_incomplete()`（脏行不入库）、`_key_text()`（`<NA>/nan/1244.0` 归一化）、同一分数多份一分一段表取累计更大者、来源 `disabled` 支持
- `pipeline/derive.py`：新增 `aggregate_university_meta()`（按规范名聚合院校 → 2700 所，解决招生代码跨省不同导致的膨胀）、`merge_university_meta()` 改为按名合并
- `pipeline/build.py`：`_read_staging` 增加省份过滤（修"每省产物写成全国全量"）；`build --all` 支持一次导出全部省份
- `pipeline/providers/base.py`：`clean_text()` 去掉 U+FFFD 与控制字符（修 CSV 列数错乱导致下一轮回读 ParserError）
- `pipeline/providers/hf_csv.py`：读取带 `encoding_errors="replace"` + `on_bad_lines="warn"`
- `pipeline/providers/manual.py`：HTML 反爬页检测（不再把网页当 CSV 解析）
- `pipeline/validate.py` + `pipeline/config.py`：新增 `max_score`（海南 900）
- `configs/provinces/`：山西、河南专业线停用；新疆/西藏改文理分科（理科/文科）；海南 `max_score = 900`
- 新增 `tests/test_batch_staging.py`（7 项）+ `tests/test_derive_university.py`；全量 **112 passed**

### 上一轮

- 新增 `pipeline/providers/prov_pdf.py` + `tests/test_prov_pdf.py`（12 个用例，含真实 PDF 端到端冒烟）
- `pipeline/providers/base.py`：抽出 `MissingArchive` / `local_dataset_path` / `archive_dest`，`hf_csv` 与 `prov_pdf` 共用本地副本路径规则
- `pipeline/config.py` + `fetch.py`：`SourceSpec.url_overrides`（按年份直连）
- `pipeline/run.py`：`options.track` 单轨来源、`archive_dest` 统一本地路径、`--all` 不再要求 `--prov`、多省跑完统一校验、`local_only` 来源清单支持 PDF
- `pipeline/parse.py`：登记 `prov_pdf`
- `configs/provinces/`：新增 30 份省份配置骨架（河南保留原有含 PDF 的完整配置）
- `tests/test_config.py`：新增"仓库内所有配置可跑"的参数化用例
- `src/data/universities.ts`：修正 6 所陕西高校省份 id
- 修「智能生成志愿表」静默失败：`lib/recommend.ts` 的 `autoFill` 挑不出院校时不再返回空数组覆盖原志愿表（低分段 0 条时会**清空用户已有志愿**），`Home` / `MyList` 增加可见降级提示
- 修老版本账号白屏：`lib/storage.ts` 读取账号时补齐 `cities` / `majors` / `subjects` / `volunteers` 默认值（旧 localStorage 缺字段会在 `<Home>` 渲染时抛 `Cannot read properties of undefined (reading 'length')`）
