import Foundation

/**
 * 内置官方数据加载器。
 *
 * 一分一段表与院校投档线随 App 打包在 `Resources/Data/official/{provId}_{rank,admission,major}.csv`，
 * 由数据管道（data-pipeline）从各省教育考试院公开信息整理后生成。
 * App 按考生档案里的高考省份自动装载对应文件 —— 用户不需要自己找数据、导入数据，也不需要校准分数线。
 */

/// 某省内建数据的覆盖情况，用于「我的 → 数据覆盖」展示
struct OfficialCoverage {
    var tables: Int = 0
    var points: Int = 0
    var admissions: Int = 0
    var majors: Int = 0
    var years: [Int] = []

    var isEmpty: Bool { tables == 0 && admissions == 0 }
}

final class OfficialData {
    static let shared = OfficialData()

    private static let dir = "official"

    private let lock = NSLock()
    private var cache: [String: OfficialDataset] = [:]

    /// 已内置数据的省份（provId 集合），从包内目录枚举，新增省份无需改代码
    private lazy var bundled: Set<String> = {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent(Self.dir),
              let files = try? FileManager.default.contentsOfDirectory(atPath: root.path)
        else { return [] }
        let suffix = "_rank.csv"
        return Set(files.compactMap { $0.hasSuffix(suffix) ? String($0.dropLast(suffix.count)) : nil })
    }()

    func hasData(_ provId: String) -> Bool { bundled.contains(provId) }

    /// 装载某省内建数据：先导入一分一段表，再导入投档线（投档线位次会按一分一段表复核）
    func dataset(provId: String, year: Int, track: Track) -> OfficialDataset {
        lock.lock()
        let hit = cache[provId]
        lock.unlock()
        if let hit { return hit }
        var ds = OfficialDataset.empty
        // CSV 自带省份 / 年份 / 科类列，ctx 仅作缺列时的兜底
        let ctx = ImportContext(provId: provId, year: year, track: track)
        if let t = text("\(provId)_rank.csv") { _ = importRankCsv(t, ctx: ctx, into: &ds) }
        if let t = text("\(provId)_admission.csv") { _ = importAdmissionCsv(t, ctx: ctx, into: &ds) }
        if let t = text("\(provId)_major.csv") { _ = importMajorAdmissionCsv(t, ctx: ctx, into: &ds) }
        lock.lock()
        cache[provId] = ds
        lock.unlock()
        return ds
    }

    func coverage(provId: String, year: Int, track: Track) -> OfficialCoverage {
        guard hasData(provId) else { return OfficialCoverage() }
        let ds = dataset(provId: provId, year: year, track: track)
        var c = OfficialCoverage()
        c.tables = ds.rankTables.count
        c.points = ds.rankTables.reduce(0) { $0 + $1.points.count }
        c.admissions = ds.admissions.count
        c.majors = ds.majorAdmissions.count
        c.years = Array(Set(ds.rankTables.map(\.year) + ds.admissions.map(\.year) + ds.majorAdmissions.map(\.year))).sorted()
        return c
    }

    private func text(_ file: String) -> String? {
        let name = (file as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "csv", subdirectory: Self.dir),
              let s = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return s
    }
}

extension OfficialData: @unchecked Sendable {}
extension DataStore: @unchecked Sendable {}
