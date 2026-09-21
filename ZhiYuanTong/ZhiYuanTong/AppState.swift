import Foundation
import SwiftUI

/// 全局状态：档案、官方数据集、志愿表、匹配结果。全部只存本机。
@MainActor
final class AppState: ObservableObject {
    /// 底部五个页签，供「智能生成志愿表 → 跳转志愿表」使用
    enum AppTab: String, CaseIterable {
        case home, explore, list, career, me
    }

    @Published var tab: AppTab = .home
    @Published var profile: StudentProfile?
    @Published var volunteers: [VolunteerItem] = []
    @Published var rank: Double = 0
    @Published var cur: CurrentLines
    @Published var evals: [Evaluated] = []
    /// 当前批次（BatchKind.rawValue）：各省批次分开生成志愿表，互不覆盖
    @Published var currentBatch: String = BatchKind.undergrad.rawValue
    /// 当前批次的院校评估（只含该批次有投档线的院校）
    @Published var batchEvals: [Evaluated] = []
    @Published var trend: [ProvinceTrendPoint] = []
    @Published var locked = false
    @Published var isLoading = false

    private(set) var engine: AdmissionEngine
    private let store = DataStore.shared

    /// 当前生效的官方数据：随 App 内置，按考生高考省份自动装载
    var dataset: OfficialDataset { engine.dataset }

    /// 内置数据的覆盖情况（一分一段表 / 投档线），供「我的」页展示
    var coverage: OfficialCoverage {
        guard let p = profile else { return OfficialCoverage() }
        return OfficialData.shared.coverage(provId: p.provId, year: store.currentYear, track: p.track)
    }

    var prov: Province { store.province(profile?.provId ?? "") }

    var currentBatchKind: BatchKind { BatchKind(rawValue: currentBatch) ?? .undergrad }

    /// 该省按分数可填的批次（本科线下只剩专科批次）；没有规则数据的省返回空，退回「不按批次」的单表模式
    var availableBatches: [BatchRuleDTO] {
        guard let p = profile, let rules = store.batches(of: p.provId) else { return [] }
        return fillableBatches(
            rules.sorted, score: p.score,
            lines: prov.lines(year: store.currentYear, track: p.track)
        )
    }

    /// 该批次的志愿数上限等规则（无规则时返回 nil，按默认 42 个的旧口径生成）
    func rule(of batch: BatchKind) -> BatchRuleDTO? {
        availableBatches.first { $0.batchKind == batch }
    }

    /// 按批次评估：只含该批次有投档线的院校
    func evals(for batch: BatchKind) -> [Evaluated] {
        guard let p = profile else { return [] }
        let records = engine.buildRecords(provId: p.provId, track: p.track, batch: batch)
        return records.map { engine.evaluateUni($0, studentScore: p.score, studentRank: rank, curSpecial: cur.special) }
    }

    /// 按考生分数默认的批次：本科线上本科批，线下专科批
    private var defaultBatch: BatchKind {
        (profile?.score ?? 0) >= cur.undergrad ? .undergrad : .college
    }

    init() {
        // 数据集不再存本机：内置数据随 App 分发，旧版本存下来的数据集直接清掉
        LocalStore.shared.clearDataset()
        engine = AdmissionEngine(dataset: .empty)
        let p = store.provinces[0]
        let l = p.linesUpTo(year: store.currentYear, track: .phy)!
        cur = CurrentLines(special: l.special, undergrad: l.undergrad, college: l.college)

        if let sid = LocalStore.shared.loadSession(),
           let found = LocalStore.shared.loadUsers().first(where: { $0.id == sid }) {
            profile = found
            volunteers = LocalStore.shared.loadVolunteers(sid)
            locked = LocalStore.shared.isBioLockEnabled
        }
        recompute()
    }

    /// 就业预测首次计算较慢，装载完内置数据后预热一次
    private var warmed = false

    // MARK: - 异步重算

    private var recomputeTask: Task<Void, Never>?
    /// 重算代号：只有最后一次任务的结果允许写回，避免快速改分数时旧结果覆盖新结果
    private var recomputeGen = 0

    private func warmEmployment() {
        guard !warmed else { return }
        warmed = true
        let ds = engine.dataset
        Task.detached(priority: .utility) { _ = EmploymentModel.allForecasts(ds) }
    }

    // MARK: - 计算

    /**
     * 异步重算：装载省内置数据 + 构建索引 + 全量院校匹配都在后台线程跑，
     * 首屏先渲染，算完再刷新（`isLoading` 期间各页显示装载提示）。
     * 之前这些全在 @MainActor 同步执行，Debug 下会卡住启动好几秒。
     */
    func recompute() {
        recomputeTask?.cancel()
        guard let p = profile else { return }
        isLoading = true
        recomputeGen += 1
        let gen = recomputeGen
        let input = RecomputeInput(
            provId: p.provId, track: p.track, score: p.score, rank: p.rank,
            override: Recommend.override(of: p), year: store.currentYear
        )
        recomputeTask = Task.detached(priority: .userInitiated) { [self] in
            let result = computeRecompute(input)
            await MainActor.run {
                guard gen == recomputeGen else { return }
                apply(result)
            }
        }
    }

    private func apply(_ r: RecomputeResult) {
        engine.dataset = r.dataset
        engine.admissionIndex = r.admissionIndex
        engine.batchIndex = r.batchIndex
        cur = r.cur
        rank = r.rank
        evals = r.evals
        trend = r.trend
        // 换省或改分数后，原来选的批次可能已经不可填（如本科线下选了本科批）→ 回退到默认批次
        if !availableBatches.contains(where: { $0.batchKind.rawValue == currentBatch }) {
            currentBatch = defaultBatch.rawValue
        }
        reloadBatchEvals()
        warmEmployment()
        isLoading = false
        recomputeTask = nil
    }

    // MARK: - 档案

    func signIn(phone: String, name: String, provId: String, track: Track, score: Double) {
        let users = LocalStore.shared.loadUsers()
        let id = "u-\(phone)"
        let existing = users.first { $0.id == id }
        var p = existing ?? StudentProfile(
            id: id, phone: phone, name: name, provId: provId, track: track,
            score: score, rank: nil, subjects: [], cities: [], majors: [],
            obeyAdjust: true, linesOverride: nil, createdAt: Date().timeIntervalSince1970 * 1000,
            strategy: .balanced, preferProvince: true, hotMajors: []
        )
        if existing != nil {
            p.name = name
            p.provId = provId
            p.track = track
            p.score = score
        }
        LocalStore.shared.upsert(p)
        LocalStore.shared.saveSession(id)
        profile = p
        volunteers = LocalStore.shared.loadVolunteers(id)
        recompute()
    }

    func update(_ mutate: (inout StudentProfile) -> Void) {
        guard var p = profile else { return }
        mutate(&p)
        profile = p
        LocalStore.shared.upsert(p)
        recompute()
    }

    func logout() {
        LocalStore.shared.saveSession(nil)
        profile = nil
        volunteers = []
        evals = []
        locked = false
    }

    /// 删除本账号在本机上的全部数据
    func deleteAccount() {
        guard let p = profile else { return }
        var users = LocalStore.shared.loadUsers()
        users.removeAll { $0.id == p.id }
        LocalStore.shared.saveUsers(users)
        LocalStore.shared.saveVolunteers([], p.id)
        logout()
    }

    // MARK: - 志愿表

    /// 切换当前批次并重算该批次的院校评估（只含该批次有投档线的院校）
    func selectBatch(_ batch: BatchKind) {
        currentBatch = batch.rawValue
        reloadBatchEvals()
    }

    private func reloadBatchEvals() {
        guard profile != nil else { batchEvals = []; return }
        batchEvals = evals(for: currentBatchKind)
    }

    func addVolunteer(_ name: String, batch: String? = nil) {
        let b = batch ?? currentBatch
        guard volunteers.first(where: { $0.uniName == name && $0.batch == b }) == nil else { return }
        let kind = BatchKind(rawValue: b) ?? .undergrad
        // 优先用该批次的评估；该校该批次没投档线（多半是不在这个批次招生）时退回主批次口径并提示
        if let target = evals(for: kind).first(where: { $0.rec.seed.name == name }) {
            volunteers.append(volunteerItem(name, target, b, nil))
        } else if let target = evals.first(where: { $0.rec.seed.name == name }) {
            volunteers.append(
                volunteerItem(name, target, b, "该校在「\(kind.label)」没有投档线数据，填报前请确认这个批次是否在我省招生")
            )
        } else { return }
        saveVolunteers()
    }

    private func volunteerItem(_ name: String, _ target: Evaluated, _ batch: String, _ note: String?) -> VolunteerItem {
        VolunteerItem(
            uniName: name,
            tier: target.tier == "险" ? "冲" : target.tier,
            prob: target.prob,
            note: note,
            batch: batch
        )
    }

    /// 删除志愿：同一院校可能同时出现在本科批与专科批，按批次删
    func removeVolunteer(_ name: String, batch: String? = nil) {
        let b = batch ?? currentBatch
        volunteers.removeAll { $0.uniName == name && $0.batch == b }
        saveVolunteers()
    }

    /// 批次内调整顺序：传的是该批次内的序号，内部映射回全局下标
    func moveVolunteer(inBatch batch: String, from offsets: IndexSet, to offset: Int) {
        let slots = volunteers.indices.filter { volunteers[$0].batch == batch }
        var rows = slots.map { volunteers[$0] }
        rows.move(fromOffsets: offsets, toOffset: offset)
        for (slot, global) in slots.enumerated() { volunteers[global] = rows[slot] }
        saveVolunteers()
    }

    /// 清空当前批次的志愿
    func clearVolunteers() {
        volunteers.removeAll { $0.batch == currentBatch }
        saveVolunteers()
    }

    /// 清空全部批次的志愿
    func clearAllVolunteers() {
        volunteers = []
        saveVolunteers()
    }

    /// 按向导收集的偏好生成**所选批次**的志愿表，写回偏好并跳转到志愿表页；
    /// 只替换同批次的志愿（本科批与专科批分别生成、互不影响），
    /// 挑不出 ≥15% 概率的院校时返回 `items` 为空的结果，**不清空已有志愿表**
    @discardableResult
    func generateVolunteers(prefs: Recommend.GenPrefs) -> Recommend.GenResult {
        let batch = prefs.batchKind
        let res = Recommend.genVolunteers(evals(for: batch), prefs: prefs, ds: engine.dataset)
        guard !res.items.isEmpty else { return res }
        update { p in
            p.cities = prefs.cities
            p.majors = prefs.disciplines
            p.hotMajors = prefs.hotMajors
            p.obeyAdjust = prefs.obeyAdjust
            p.preferProvince = prefs.preferProvince
            p.strategy = prefs.strategy
        }
        volunteers = volunteers.filter { $0.batch != batch.rawValue } + res.items
        saveVolunteers()
        currentBatch = batch.rawValue
        reloadBatchEvals()
        tab = .list
        return res
    }

    private func saveVolunteers() {
        guard let id = profile?.id else { return }
        LocalStore.shared.saveVolunteers(volunteers, id)
    }

    // MARK: - 官方数据

    /// 某校在当前档案下的专业级评估（内置「专业录取线」的省份才有点开的意义）
    func majorEvals(_ uniName: String) -> [MajorEval] {
        guard let p = profile else { return [] }
        let rows = findMajorAdmissions(engine.dataset, uniName, p.provId, p.track, store.currentYear)
        guard !rows.isEmpty else { return [] }
        return engine.evaluateMajors(
            rows, prov: prov,
            studentScore: p.score, studentRank: rank, subjects: p.subjects,
            override: Recommend.override(of: p)
        )
    }

}

// MARK: - 后台重算（放在顶层：detached 任务里不能引用主线程隔离类型的 self）

/// 跨线程只传值：不含 AppState / AdmissionEngine
struct RecomputeInput: @unchecked Sendable {
    var provId: String
    var track: Track
    var score: Double
    var rank: Double?
    var override: CurrentLines?
    var year: Int
}

struct RecomputeResult: @unchecked Sendable {
    var dataset: OfficialDataset
    var admissionIndex: [String: OfficialAdmission]
    var batchIndex: [String: OfficialAdmission]
    var cur: CurrentLines
    var rank: Double
    var evals: [Evaluated]
    var trend: [ProvinceTrendPoint]
}

/// 后台纯计算：自建 engine 实例，不碰主线程状态
private func computeRecompute(_ input: RecomputeInput) -> RecomputeResult {
    let store = DataStore.shared
    let prov = store.province(input.provId)
    let ds = OfficialData.shared.dataset(provId: input.provId, year: input.year, track: input.track)
    let engine = AdmissionEngine(store: store, dataset: ds)
    let cur = engine.currentLines(prov, input.track, override: input.override)
    let rank = input.rank ?? engine.rankOfScore(prov, input.year, input.track, input.score)
    let records = engine.buildRecords(provId: input.provId, track: input.track)
    let evals = records.map { engine.evaluateUni($0, studentScore: input.score, studentRank: rank, curSpecial: cur.special) }
    let trend = engine.provinceTrend(prov, input.track, override: input.override)
    return RecomputeResult(
        dataset: ds,
        admissionIndex: engine.admissionIndex,
        batchIndex: engine.batchIndex,
        cur: cur,
        rank: rank,
        evals: evals,
        trend: trend
    )
}

extension StudentProfile {
    static var placeholder: StudentProfile {
        StudentProfile(
            id: "", phone: "", name: "", provId: DataStore.shared.provinces[0].id, track: .phy,
            score: 0, rank: nil, subjects: [], cities: [], majors: [],
            obeyAdjust: true, linesOverride: nil, createdAt: 0,
            strategy: .balanced, preferProvince: true, hotMajors: []
        )
    }
}
