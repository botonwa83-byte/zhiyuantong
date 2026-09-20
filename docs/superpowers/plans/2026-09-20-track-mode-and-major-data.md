# 科类口径修正与专业级数据演进 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 App 的科类建模错误（3+3 省份不应出现"物理类/历史类"，新疆/西藏仍是文理分科），并把"专业级录取数据"与"外部数据接入"拆成后续可独立执行的计划。

**Architecture:** 数据集（TypeScript）→ `sync-data.sh` 导出 `bundle.json` → 原生 SwiftUI 消费。科类名称不再由 `Track` 单独决定，而是由 **考试模式 × Track** 共同决定：新增 `ExamMode.old`（文理分科），新增全局函数 `trackLabel(_:_:)`；3+3 省份在 UI 层隐藏科类选择器、统一显示"综合"。专业级数据后续以新契约表 `major_admission` 进入现有 Python 管道与 `OfficialDataset`。

**Tech Stack:** Swift 5.9 / SwiftUI（iOS 17.0+、macOS 14.0+）、TypeScript 数据集 + esbuild 导出脚本（`ZhiYuanTong/Scripts/`）、Python 数据管道（`data-pipeline/`）。

**执行状态（2026-09-20）：** Task 1–3 已完成；Task 4 编译与数据校验已通过，**模拟器手测清单待人工确认**；Plan B / Plan C 为后续独立计划。

**Spec:** 无独立 spec。依据 `docs/NEXT_STEPS.md` §二.4（省份范围以 App 为准）、§3.6（原生版为唯一实现），以及 2026-09-20 会话核实的三条事实：
1. 河南是 **3+1+2**（语数外 + 首选物理/历史 + 再选 2 门），不是"3+2"；官方一分一段表、批次线、投档线**按首选科目分物理类/历史类分别公布**，故现有 `phy/his` 建模本身正确（来源：河南教育考试院 2025-06-25 发布，搜狐/今日头条转载）。
2. **3+3 六省**（山东、浙江、北京、天津、上海、海南）不分科类，只有一个综合位次。
3. **新疆、西藏 2024 年秋季高一才启动改革、2027 年首考**，2022–2026 届仍是老高考文理分科（理科/文科）。

## Global Constraints

- App 唯一实现是原生 SwiftUI 工程 `ZhiYuanTong/ZhiYuanTong.xcodeproj`；Web（React/Vite/Capacitor）版已整体删除，不要再新建前端目录。
- 数据集源文件在 `ZhiYuanTong/Scripts/data/*.ts` + `ZhiYuanTong/Scripts/types.ts`；改完必须 `bash ZhiYuanTong/Scripts/sync-data.sh` 再在 Xcode 重新编译，否则真机无变化。
- **不要用 xcodegen 重新生成 `project.pbxproj`**（`DEVELOPMENT_TEAM = Z7F8BY55DS` 等签名设置会丢失）；新增文件手工登记进 iOS + macOS 两个 target。
- 数据获取：只读本地 + 人工下载。不爬商业站点（掌上高考等）的非公开内部 API；它只作人工核对/人工导出来源。
- 老存档兼容：`StudentProfile` 新增字段必须自定义 `Decodable` 给默认值，不能丢档。
- 缺数据一律降级显示「暂无官方数据」，**不编造数值**。
- 省份 id 沿用现值（`xinjiang` / `xizang` / `shaanxi` 陕西 / `shanxi` 山西），不得改名。

---

## Task 1: 数据层——新增「文理分科」模式

**Files:**
- Modify: `ZhiYuanTong/Scripts/types.ts:5`（`ExamMode` 联合类型）
- Modify: `ZhiYuanTong/Scripts/data/provincesExtra.ts:113-124`（新疆、西藏的 mode 与 2025 批次线）
- Modify: `ZhiYuanTong/Scripts/export-data.ts`（导出前一致性校验）
- Produce: `ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json`

**Interfaces:**
- Consumes: `Province`/`ExamMode`（`ZhiYuanTong/Scripts/types.ts`）、`extraProvinces`（`provincesExtra.ts`）
- Produces: `bundle.json` 中 `provinces[].mode ∈ {"3+1+2","3+3","文理分科"}`，供 Task 2 的 `ExamMode(rawValue:)` 解码

- [x] **Step 1: 扩展 ExamMode 联合类型**

```ts
// ZhiYuanTong/Scripts/types.ts
export type ExamMode = '3+1+2' | '3+3' | '文理分科'
```

- [x] **Step 2: 新疆、西藏改为文理分科，并修正新疆 2025 批次线**

`provincesExtra.ts` 行格式为 `[year, 理/物 special, undergrad, college, 文/历 special, undergrad, college, candidates(万), ugPlan(万)]`。
新疆 2025 官方：理科一批 421 / 二批 280 / 专科 140；文科一批 451 / 二批 330 / 专科 140（新疆教育考试院 2025-06-25 公布）。

```ts
  // 新疆、西藏：2024 年秋季高一才启动新高考，2027 年首考；2022–2026 届为文理分科（前三项理科、后三项文科）
  ['xinjiang', '新疆', '文理分科', [
    [2022, 400, 290, 140, 443, 334, 140, 21.0, 9.5],
    [2023, 396, 285, 140, 458, 354, 140, 22.0, 9.8],
    [2024, 390, 262, 140, 425, 304, 140, 23.2, 10.2],
    [2025, 421, 280, 140, 451, 330, 140, 23.5, 10.4],
  ]],
  ['xizang', '西藏', '文理分科', [
    [2022, 305, 260, 200, 340, 305, 200, 3.2, 1.5],
    [2023, 300, 255, 200, 320, 282, 200, 3.3, 1.55],
    [2024, 300, 265, 200, 335, 301, 200, 3.4, 1.6],
    [2025, 302, 266, 200, 336, 302, 200, 3.5, 1.65],
  ]],
```

- [x] **Step 3: 在 export-data.ts 加导出前校验**

在 `writeFileSync` 之前插入：

```ts
const MODES = new Set<Province['mode']>(['3+1+2', '3+3', '文理分科'])
for (const p of bundle.provinces) {
  if (!MODES.has(p.mode)) throw new Error(`未知考试模式：${p.name}(${p.id}) = ${p.mode}`)
  if (p.mode === '3+3') {
    const bad = p.lines.filter((l) => l.track === 'phy' && !p.lines.some((o) =>
      o.year === l.year && o.track === 'his' && o.special === l.special &&
      o.undergrad === l.undergrad && o.college === l.college))
    if (bad.length) throw new Error(`${p.name} 为 3+3，物理/历史两轨必须一致，异常年份：${bad.map((b) => b.year).join(',')}`)
  }
}
```

- [x] **Step 4: 重新生成 bundle.json 并核对**

Run: `bash ZhiYuanTong/Scripts/sync-data.sh`
Expected: 输出 `省份 31 · 院校 346 · …`，无异常抛出。

Run:
```bash
node -e "const b=require('./ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json');console.log(b.provinces.filter(p=>['xinjiang','xizang'].includes(p.id)).map(p=>p.id+':'+p.mode).join(' '))"
```
Expected: `xinjiang:文理分科 xizang:文理分科`

- [ ] **Step 5: 提交**（阻塞：仓库未初始化 git，无 `.git`，需先 `git init`）

```bash
git add ZhiYuanTong/Scripts ZhiYuanTong/ZhiYuanTong/Resources/Data/bundle.json
git commit -m "fix(data): 新疆/西藏改为文理分科，修正新疆2025批次线"
```

---

## Task 2: Swift 模型层——ExamMode 扩类与科类命名

**Files:**
- Modify: `ZhiYuanTong/ZhiYuanTong/Models.swift:4-16`（`Track` / `ExamMode` / `trackLabel`）
- Modify: `ZhiYuanTong/ZhiYuanTong/Engine.swift:61-66`（`candidatesOf`）

**Interfaces:**
- Consumes: `bundle.json` 的 `mode` 字段（Task 1 产出）
- Produces: `trackLabel(_:_:)` → 供 Task 3 的 `RootView` / `MeView` / `HomeView` 使用；`ExamMode.old`

- [x] **Step 1: ExamMode 新增 `.old` 并实现容错编解码**

```swift
enum ExamMode: String, Codable {
    case t312 = "3+1+2"
    case t33 = "3+3"
    case old = "文理分科"     // 新疆、西藏：2027 年才首考新高考

    // 未识别取值（老 bundle / 脏数据）退回 3+1+2，避免整份数据集解码失败
    init(from decoder: Decoder) throws {
        let v = try decoder.singleValueContainer().decode(String.self)
        self = ExamMode(rawValue: v) ?? .t312
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
```

- [x] **Step 2: 新增科类命名函数**

```swift
/// 科类名称随考试模式变化：3+1+2 → 物理类/历史类；3+3 → 综合；文理分科 → 理科/文科
func trackLabel(_ track: Track, _ mode: ExamMode) -> String {
    switch mode {
    case .t312: return track == .phy ? "物理类" : "历史类"
    case .t33:  return "综合"
    case .old:  return track == .phy ? "理科" : "文科"
    }
}
```

`Track.label` 保留（等同 3+1+2 文案），但 UI 层一律改用 `trackLabel(_:_:)`。

- [x] **Step 3: 考生数拆分区分老高考**

```swift
    func candidatesOf(_ prov: Province, _ year: Int, _ track: Track) -> Double {
        let total = linesOf(prov, year, track).candidates
        switch prov.mode {
        case .t33:  return total                                        // 不分科类
        case .old:  return track == .phy ? total * 0.68 : total * 0.32  // 老高考理科约占 2/3
        case .t312: return track == .phy ? total * 0.62 : total * 0.38  // 物理 62% / 历史 38%
        }
    }
```

- [ ] **Step 4: 提交**（阻塞：仓库未初始化 git，无 `.git`，需先 `git init`）

```bash
git add ZhiYuanTong/ZhiYuanTong/Models.swift ZhiYuanTong/ZhiYuanTong/Engine.swift
git commit -m "feat(swift): ExamMode 支持文理分科，科类名称按考试模式生成"
```

---

## Task 3: UI——科类选择器按考试模式自适应

**Files:**
- Modify: `ZhiYuanTong/ZhiYuanTong/RootView.swift:77-83`（注册/登录页科类选择器）
- Modify: `ZhiYuanTong/ZhiYuanTong/MeView.swift:207-210`（档案页科类选择器）
- Modify: `ZhiYuanTong/ZhiYuanTong/HomeView.swift:90`（首页科类文案）

**Interfaces:**
- Consumes: `trackLabel(_:_:)`（Task 2）、`DataStore.shared.provinces`、`ExamMode`
- Produces: 面向用户的科类展示与录入

- [x] **Step 1: RootView 科类选择器——3+3 隐藏**

```swift
                        let mode = DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312
                        if mode != .t33 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("科类").font(.caption).foregroundStyle(Color.ink500)
                                Picker("科类", selection: $track) {
                                    Text(trackLabel(.phy, mode)).tag(Track.phy)
                                    Text(trackLabel(.his, mode)).tag(Track.his)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
```

- [x] **Step 2: MeView 档案页同样处理，并在切到 3+3 省份时把 track 归位**

```swift
                    let mode = DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312
                    if mode != .t33 {
                        Picker("科类", selection: $track) {
                            Text(trackLabel(.phy, mode)).tag(Track.phy)
                            Text(trackLabel(.his, mode)).tag(Track.his)
                        }
                    }
```
并在 `MeView` 的省份 `Picker` 后追加 `.onChange(of: provId) { if mode == .t33 { track = .phy } }`（3+3 只有一条轨，避免残留 `.his` 取不到线）。

- [x] **Step 3: HomeView 统一走 trackLabel**

```swift
            Text("\(prov.name) · \(trackLabel(profile.track, prov.mode)) · \(state.engine.batchOf(profile.score, cur))")
```

- [ ] **Step 4: 提交**（阻塞：仓库未初始化 git，无 `.git`，需先 `git init`）

```bash
git add ZhiYuanTong/ZhiYuanTong/RootView.swift ZhiYuanTong/ZhiYuanTong/MeView.swift ZhiYuanTong/ZhiYuanTong/HomeView.swift
git commit -m "fix(ui): 3+3 省份隐藏科类选择器，文理分科省份显示理科/文科"
```

---

## Task 4: 编译与验收

**Files:**
- Modify: `docs/NEXT_STEPS.md`（新增「科类口径」小节与已知坑）

- [x] **Step 1: 数据校验脚本复跑**

Run: `bash ZhiYuanTong/Scripts/sync-data.sh` → 成功，无校验异常。

- [x] **Step 2: 两个 target 编译**

```bash
xcodebuild -project ZhiYuanTong/ZhiYuanTong.xcodeproj -scheme ZhiYuanTong -destination 'generic/platform=iOS Simulator' build
xcodebuild -project ZhiYuanTong/ZhiYuanTong.xcodeproj -scheme ZhiYuanTongMac build
```
Expected: 两者 `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 模拟器手测清单**

| 场景 | 期望 |
| --- | --- |
| 新建档案 → 省份选"山东" | 科类选择器消失，首页显示"山东 · 综合" |
| 省份选"新疆" | 显示"理科 / 文科" |
| 省份选"河南" | 显示"物理类 / 历史类" |
| 老账号（已存档案）登录 | 正常进入，不丢档，科类文案随省份模式变化 |
| 首页位次/概率 | 新疆理科位次按 0.68 拆分，不再是 0.62 |

- [ ] **Step 4: 更新 NEXT_STEPS.md**

在「四、已知坑」追加：3+3 六省不分科类；新疆/西藏 2027 才首考新高考（2022–2026 届文理分科）；`trackLabel(_:_:)` 是科类文案唯一入口。
在「三、待办清单」追加本次未做的两项（专业级数据、外部数据接入）并指向后续计划。

- [ ] **Step 5: 提交**

```bash
git add docs/NEXT_STEPS.md
git commit -m "docs: 记录科类口径修正与后续数据演进计划"
```

---

## 后续计划（各自独立成 plan，本次不执行）

### Plan B：专业级录取数据 `major_admission`
- 契约：`(prov_id, year, track, uni_code, uni_name, major_group, major_name, subject_req, plan, min_score, min_rank)`，加进 `data-pipeline/pipeline/contract.py` 的 `TableSpec.columns`（**注意：`prov` 会被 `prov_id` 别名抢走，新增列必须避开 `province`/`prov`**）。
- 管道：新增 kind `major_admission` + `manual` 来源；`providers/prov_pdf.py` 复用考试院 PDF 解析；产物按省分包。
- App：`Dataset.swift` 新增 `MajorAdmission` 与 `findMajorAdmission`；`Engine` 增加专业级等效分/概率；`Recommend.swift` 生成志愿时按 `subject_req` **硬过滤**不满足选科的院校专业组（3+1+2 的"物理+化学"等）。
- 验收：河南 2025 某校专业级数据导入后，专业级最低位次与官方公布值一致；选科不满足的组合不出现在志愿表里。

### Plan C：外部数据接入（掌上高考仅作人工核对/导出）
- 掌上高考（`m.gaokao.cn`，中国教育在线旗下）数据到专业级，但它同样是二次聚合、接口非公开且有反爬与服务条款约束 → **只做人工浏览器查询与人工导出**，不写爬虫。
- 导出规范：`data-pipeline/raw/<prov_id>/<year>/major_admission_<来源>.csv`，列名用 `Dataset.swift:64-72` 已登记的别名（科类列兼容「科类/类别/科目/文理/选科」），进 `manual` provider。
- 一手源优先：各省教育考试院一分一段 PDF / 投档线、阳光高考 `gaokao.chsi.com.cn`（招生章程、专业库）、院校就业质量报告。
- 验收：31 省 × 3 年一分一段 + 投档线入库；掌上高考抽查 20 个院校专业组合，与推算值偏差 > 5 分的进复核队列。
