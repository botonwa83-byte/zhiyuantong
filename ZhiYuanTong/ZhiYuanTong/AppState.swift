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
    @Published var trend: [ProvinceTrendPoint] = []
    @Published var locked = false
    @Published var isLoading = false

    private(set) var engine: AdmissionEngine
    private let store = DataStore.shared

    var dataset: OfficialDataset {
        get { engine.dataset }
        set {
            engine.dataset = newValue
            LocalStore.shared.saveDataset(newValue)
            objectWillChange.send()
            recompute()
        }
    }

    var prov: Province { store.province(profile?.provId ?? "") }

    init() {
        let ds = LocalStore.shared.loadDataset()
        engine = AdmissionEngine(dataset: ds)
        let p = store.provinces[0]
        let l = p.lines(year: store.currentYear, track: .phy) ?? p.lines(year: 2024, track: .phy)!
        cur = CurrentLines(special: l.special, undergrad: l.undergrad, college: l.college)

        if let sid = LocalStore.shared.loadSession(),
           let found = LocalStore.shared.loadUsers().first(where: { $0.id == sid }) {
            profile = found
            volunteers = LocalStore.shared.loadVolunteers(sid)
            locked = LocalStore.shared.isBioLockEnabled
        }
        recompute()
        // 预热就业预测（346 所院校，首次约耗时百毫秒级）
        Task.detached(priority: .utility) {
            _ = EmploymentModel.allForecasts(ds)
        }
    }

    // MARK: - 计算

    func recompute() {
        guard let p = profile else { return }
        let prov = store.province(p.provId)
        let override = Recommend.override(of: p)
        cur = engine.currentLines(prov, p.track, override: override)
        rank = p.rank ?? engine.rankOfScore(prov, store.currentYear, p.track, p.score)
        let records = engine.buildRecords(provId: p.provId, track: p.track)
        evals = records.map { engine.evaluateUni($0, studentScore: p.score, studentRank: rank, curSpecial: cur.special) }
        trend = engine.provinceTrend(prov, p.track, override: override)
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

    func addVolunteer(_ name: String) {
        guard volunteers.first(where: { $0.uniName == name }) == nil,
              let target = evals.first(where: { $0.rec.seed.name == name })
        else { return }
        volunteers.append(
            VolunteerItem(
                uniName: name,
                tier: target.tier == "险" ? "冲" : target.tier,
                prob: target.prob,
                note: nil
            )
        )
        saveVolunteers()
    }

    func removeVolunteer(_ name: String) {
        volunteers.removeAll { $0.uniName == name }
        saveVolunteers()
    }

    func moveVolunteer(from offsets: IndexSet, to offset: Int) {
        volunteers.move(fromOffsets: offsets, toOffset: offset)
        saveVolunteers()
    }

    func clearVolunteers() {
        volunteers = []
        saveVolunteers()
    }

    /// 按向导收集的偏好生成志愿表，写回偏好并跳转到志愿表页；
    /// 挑不出 ≥15% 概率的院校时返回 `items` 为空的结果，**不清空已有志愿表**
    @discardableResult
    func generateVolunteers(prefs: Recommend.GenPrefs) -> Recommend.GenResult {
        let res = Recommend.genVolunteers(evals, prefs: prefs, ds: engine.dataset)
        guard !res.items.isEmpty else { return res }
        update { p in
            p.cities = prefs.cities
            p.majors = prefs.disciplines
            p.hotMajors = prefs.hotMajors
            p.obeyAdjust = prefs.obeyAdjust
            p.preferProvince = prefs.preferProvince
            p.strategy = prefs.strategy
        }
        volunteers = res.items
        saveVolunteers()
        tab = .list
        return res
    }

    private func saveVolunteers() {
        guard let id = profile?.id else { return }
        LocalStore.shared.saveVolunteers(volunteers, id)
    }

    // MARK: - 官方数据

    func importRank(_ text: String, ctx: ImportContext) -> ImportReport {
        var ds = engine.dataset
        let report = importRankCsv(text, ctx: ctx, into: &ds)
        if report.ok { dataset = ds }
        return report
    }

    func importAdmission(_ text: String, ctx: ImportContext) -> ImportReport {
        var ds = engine.dataset
        let report = importAdmissionCsv(text, ctx: ctx, into: &ds)
        if report.ok { dataset = ds }
        return report
    }

    func importEmployment(_ text: String) -> ImportReport {
        var ds = engine.dataset
        let report = importEmploymentCsv(text, into: &ds)
        if report.ok { dataset = ds }
        return report
    }

    /// 某校在当前档案下的专业级评估（需先导入「专业录取线」）
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

    func importMajorAdmission(_ text: String, ctx: ImportContext) -> ImportReport {
        var ds = engine.dataset
        let report = importMajorAdmissionCsv(text, ctx: ctx, into: &ds)
        if report.ok { dataset = ds }
        return report
    }

    func clearDataset() {
        LocalStore.shared.clearDataset()
        dataset = .empty
    }

    var stats: DatasetStats { datasetStats(engine.dataset) }

    var hasOfficialData: Bool {
        !engine.dataset.rankTables.isEmpty || !engine.dataset.admissions.isEmpty
            || !engine.dataset.employments.isEmpty || !engine.dataset.majorAdmissions.isEmpty
    }
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
