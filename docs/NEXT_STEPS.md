# 高考数据管道 · 下一步清单

> 更新于 2026-09-20（承接 2026-09-18 会话）。下次会话直接按本文件开工，无需重新调研。

> ⚠️ **2026-09-20 结构变更：Web 版已删除。**
> App 只有一套代码 —— 原生 SwiftUI 工程 `ZhiYuanTong/ZhiYuanTong.xcodeproj`。
> 根目录的 React/Vite/Capacitor 前端（`src/`、`index.html`、`vite.config.ts`、`capacitor.config.ts`、`public/`、`dist/`、`ios/`）已全部删除，避免「改了没反应」的误导。
> 数据集源文件（原 `src/data/*.ts`）迁到 **`ZhiYuanTong/Scripts/data/`**，仍是 `bundle.json` 的唯一来源：
> 改完数据执行 `bash ZhiYuanTong/Scripts/sync-data.sh`（或 `npm run data:ios`）重新生成 `ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json`，再在 Xcode 里重新编译。
> 根目录 `package.json` 只剩数据管道与数据导出脚本（依赖仅 `esbuild`），Web 依赖（`react`/`vite`/`@capacitor/*`）已随 `node_modules` 清理。

## 一、当前状态

工作目录：`data-pipeline/`（虚拟环境 `.venv`，命令前缀 `cd data-pipeline && .venv/bin/python -m ...`）

| 产物 / 模块 | 结果 |
| --- | --- |
| `staging/rank_table.csv` | 河南 2025，225 行（**仅物理类**） |
| `staging/admission.csv` | 河南 2025，1687 行（含专业组/选科/位次） |
| `staging/university_meta.csv` | 609 所院校（官方代码、所在地、公办/民办、985/211） |
| `dist/universities_full.csv` | 608 所，App 可直接导入（`uni_code,name,prov,city,level,kind,nature`） |
| `providers/prov_pdf.py` | **新增**：考试院一分一段 PDF 解析器（待真实 PDF 验证） |
| `configs/provinces/*.toml` | **新增**：31 省配置骨架（对齐 App 省份清单） |
| 校验 | 阻断 0 / 警告 512（位次口径偏差，进复核队列，不阻断） |
| 单测 | **87 passed**（`python -m pytest tests -q`） |

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
- [ ] 待做（下一轮）：① 档案页增加选科录入 UI（六门多选），② `Recommend` 按选科要求**硬过滤**院校专业组，③ 专业级概率（用专业线替代院校线做等效分测算）

### 4. 产物与打包（Task 8-10）
- [ ] `pipeline/build.py` 扩展：分省产物包（web/iOS），按省按需导入（单省 admission ≈ 150KB，20 省 × 3 年 ≈ 9MB）
- [ ] 复核队列：处理 512 条位次口径警告，确认是源数据问题还是解析问题

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
- **多省批量跑的告警计数**：`staging/` 是共享的，各省报告里若各自跑 `validate_staging` 会把同一批告警重复计 N 次；现已改成跑完全部省份统一校验一次，`run_report.json` 结构为 `{years, provinces[], blocking_issues, warning_issues, issues}`。
- **App 院校属地 id**：`ZhiYuanTong/Scripts/data/universities.ts` 里 6 所陕西高校（西安交大、西工大、西北农林、西电、陕师大、西安理工）曾误写 `shanxi`（山西），已修正为 `shaanxi`。新增院校数据时注意 `shanxi`(山西) / `shaanxi`(陕西) 的拼写。

## 五、常用命令

```bash
cd data-pipeline
.venv/bin/python -m pipeline.run --prov henan --year 2025            # 跑单省
.venv/bin/python -m pipeline.run --all --year 2025 --list            # 导出下载清单（--prov 不再必填）
.venv/bin/python -m pipeline.run --all --year 2025                   # 全量跑
.venv/bin/python -m pipeline.build                                    # 生成 dist/universities_full.csv
.venv/bin/python -m pytest tests -q                                   # 单测（87 passed）
cat staging/run_report.json                                           # 运行报告（含 missing/failed 来源）
```

## 六、本轮改动清单（便于 review）

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
