import Foundation

// MARK: - 一分一段表

struct RankPoint: Codable {
    var score: Double
    var rank: Double
}

struct RankTable: Codable, Identifiable {
    var provId: String
    var year: Int
    var track: Track
    /// 按分数降序
    var points: [RankPoint]

    var id: String { "\(provId)-\(year)-\(track.rawValue)" }
}

/// 通用分隔文本解析：逗号 / 制表符 / 分号，支持引号包裹
func parseCsv(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var cur = ""
    var quoted = false
    let s = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
    var i = 0
    while i < s.count {
        let ch = s[i]
        if quoted {
            if ch == "\"" {
                if i + 1 < s.count && s[i + 1] == "\"" {
                    cur.append("\"")
                    i += 1
                } else {
                    quoted = false
                }
            } else {
                cur.append(ch)
            }
        } else if ch == "\"" {
            quoted = true
        } else if ch == "," || ch == "\t" || ch == ";" {
            row.append(cur.trimmingCharacters(in: .whitespaces))
            cur = ""
        } else if ch == "\n" {
            row.append(cur.trimmingCharacters(in: .whitespaces))
            rows.append(row)
            row = []
            cur = ""
        } else {
            cur.append(ch)
        }
        i += 1
    }
    if !cur.isEmpty || !row.isEmpty {
        row.append(cur.trimmingCharacters(in: .whitespaces))
        rows.append(row)
    }
    return rows.filter { r in r.contains { !$0.isEmpty } }
}

enum ColumnKey: String, CaseIterable {
    case score, rank, uni, major, subjectReq, prov, track, year, plan, employ, further, salary, industry

    var keys: [String] {
        switch self {
        case .score: return ["分数", "总分", "成绩", "投档分", "录取分", "最低分", "文化分", "score", "minscore", "min_score"]
        case .rank: return ["位次", "最低位次", "排名", "名次", "累计", "累计人数", "累计位次", "段内位次", "rank", "minrank", "min_rank"]
        case .uni: return ["院校", "学校", "院校名称", "学校名称", "高校", "高校名称", "招生院校", "university", "school", "college", "name"]
        case .major: return ["专业名称", "招生专业", "专业类", "专业", "major"]
        case .subjectReq: return ["选科要求", "选考科目", "科目要求", "选考要求", "subjectreq"]
        case .prov: return ["省份", "省", "招生省份", "省市", "province", "prov"]
        case .track: return ["科类", "类别", "科目", "文理", "选科", "track", "category", "subject"]
        case .year: return ["年份", "年", "年度", "year"]
        case .plan: return ["计划", "计划数", "招生计划", "招生人数", "计划人数", "plan"]
        case .employ: return ["就业率", "落实率", "毕业去向落实率", "就业", "就业比例", "employment", "employrate"]
        case .further: return ["深造率", "升学率", "读研率", "考研率", "继续深造", "further", "furtherrate"]
        case .salary: return ["月薪", "平均月薪", "薪酬", "起薪", "平均薪资", "月收入", "salary", "income"]
        case .industry: return ["行业", "主要行业", "就业行业", "行业流向", "industry", "industries"]
        }
    }
}

func findColumn(_ headers: [String], _ key: ColumnKey) -> Int {
    let keys = key.keys
    for (i, h) in headers.enumerated() {
        let norm = h.lowercased().replacingOccurrences(of: "[\\s_-]", with: "", options: .regularExpression)
        if keys.contains(where: { norm.contains($0.lowercased()) }) { return i }
    }
    return -1
}

/// 找列但跳过已被占用的列：如「选科要求」同时含「选科」，不能让它抢走科类列
func findColumnExcluding(_ headers: [String], _ key: ColumnKey, excluding: Set<Int>) -> Int {
    let keys = key.keys
    for (i, h) in headers.enumerated() {
        if excluding.contains(i) { continue }
        let norm = h.lowercased().replacingOccurrences(of: "[\\s_-]", with: "", options: .regularExpression)
        if keys.contains(where: { norm.contains($0.lowercased()) }) { return i }
    }
    return -1
}

func hasHeader(_ rows: [[String]]) -> Bool {
    guard let first = rows.first else { return false }
    return ColumnKey.allCases.contains { findColumn(first, $0) >= 0 }
}

struct ImportContext {
    var provId: String
    var year: Int
    var track: Track
}

struct ParseResult<T> {
    var data: [T]
    var rows: Int
    var warnings: [String]
}

/// 名称归一：去掉括号内容与空白，便于匹配
func normalizeUniName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "[（(].*?[)）]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        .replacingOccurrences(of: "[·•]", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
}

func toNumber(_ raw: String) -> Double? {
    let v = raw.replacingOccurrences(of: "[,，\\s]", with: "", options: .regularExpression)
    guard !v.isEmpty, let n = Double(v), n.isFinite else { return nil }
    return n
}

func normalizeProvince(_ raw: String, fallback: String) -> String {
    let v = raw.trimmingCharacters(in: .whitespaces)
    if v.isEmpty { return fallback }
    let provinces = DataStore.shared.provinces
    if let hit = provinces.first(where: { $0.name == v }) { return hit.id }
    let suffix = "(省|市|自治区|壮族|回族|维吾尔|特别行政区)$"
    let short = v.replacingOccurrences(of: suffix, with: "", options: .regularExpression)
    if let hit = provinces.first(where: { $0.name == short }) { return hit.id }
    for p in provinces {
        let shortName = p.name.replacingOccurrences(of: suffix, with: "", options: .regularExpression)
        if v.contains(p.name) || v.contains(shortName) || p.name.contains(v) { return p.id }
    }
    return fallback
}

func normalizeTrack(_ raw: String, fallback: Track) -> Track {
    let v = raw.trimmingCharacters(in: .whitespaces).lowercased()
    if v.isEmpty { return fallback }
    if v.contains("历史") || v.contains("文科") || v.contains("文史") || v.contains("his") { return .his }
    if v.contains("物理") || v.contains("理科") || v.contains("理工") || v.contains("综合") || v.contains("phy") { return .phy }
    return fallback
}

// MARK: - 官方数据集

struct OfficialAdmission: Codable, Identifiable {
    var uniName: String
    var provId: String
    var track: Track
    var year: Int
    var score: Double
    var rank: Double?
    var plan: Double?

    var id: String { "\(provId)-\(track.rawValue)-\(year)-\(uniName)" }
}

struct OfficialEmployment: Codable, Identifiable {
    var uniName: String
    var year: Double?
    var employRate: Double?
    var furtherRate: Double?
    var salary: Double?
    var industries: [String]?

    var id: String { uniName }
}

/// 专业级录取线：官方/人工整理的专业录取分，带选科要求（3+1+2 省份用于硬过滤）
struct OfficialMajorAdmission: Codable, Identifiable {
    var uniName: String
    var provId: String
    var track: Track
    var year: Int
    var majorName: String
    var score: Double
    var rank: Double?
    var plan: Double?
    /// 选科要求原始文本，如「物理+化学」；空表示不限
    var subjectReq: String?
    var batch: String?

    var id: String { "\(provId)-\(track.rawValue)-\(year)-\(uniName)-\(majorName)" }

    /// 解析出要求的科目，如「物理+化学」→ ["物理", "化学"]
    var requiredSubjects: [String] {
        guard let s = subjectReq else { return [] }
        return GAOKAO_SUBJECTS.filter { s.contains($0) }
    }

    /// 考生的选科能否报这个专业：要求科目必须全部出现在考生选科里（首选科目由 track 保证）
    func meets(_ mySubjects: [String]) -> Bool {
        let req = requiredSubjects
        if req.isEmpty { return true }
        if mySubjects.isEmpty { return true } // 未填选科时不做过滤，避免误杀
        return req.allSatisfy { mySubjects.contains($0) }
    }
}

struct OfficialDataset: Codable {
    var updatedAt: Double
    var rankTables: [RankTable]
    var admissions: [OfficialAdmission]
    var employments: [OfficialEmployment]
    var majorAdmissions: [OfficialMajorAdmission]

    private enum CodingKeys: String, CodingKey {
        case updatedAt, rankTables, admissions, employments, majorAdmissions
    }

    init(
        updatedAt: Double, rankTables: [RankTable], admissions: [OfficialAdmission],
        employments: [OfficialEmployment], majorAdmissions: [OfficialMajorAdmission]
    ) {
        self.updatedAt = updatedAt
        self.rankTables = rankTables
        self.admissions = admissions
        self.employments = employments
        self.majorAdmissions = majorAdmissions
    }

    static var empty: OfficialDataset {
        OfficialDataset(updatedAt: 0, rankTables: [], admissions: [], employments: [], majorAdmissions: [])
    }

    // 老存档没有 majorAdmissions 键：缺失按空数组处理，不能整份解码失败导致丢档
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = (try? c.decode(Double.self, forKey: .updatedAt)) ?? 0
        rankTables = (try? c.decode([RankTable].self, forKey: .rankTables)) ?? []
        admissions = (try? c.decode([OfficialAdmission].self, forKey: .admissions)) ?? []
        employments = (try? c.decode([OfficialEmployment].self, forKey: .employments)) ?? []
        majorAdmissions = (try? c.decode([OfficialMajorAdmission].self, forKey: .majorAdmissions)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(rankTables, forKey: .rankTables)
        try c.encode(admissions, forKey: .admissions)
        try c.encode(employments, forKey: .employments)
        try c.encode(majorAdmissions, forKey: .majorAdmissions)
    }
}

func findRankTable(_ ds: OfficialDataset, _ provId: String, _ year: Int, _ track: Track) -> RankTable? {
    ds.rankTables.first { $0.provId == provId && $0.year == year && $0.track == track }
}

func findAdmission(_ ds: OfficialDataset, _ uniName: String, _ provId: String, _ track: Track, _ year: Int) -> OfficialAdmission? {
    let target = normalizeUniName(uniName)
    if let exact = ds.admissions.first(where: {
        $0.provId == provId && $0.track == track && $0.year == year && normalizeUniName($0.uniName) == target
    }) { return exact }
    return ds.admissions.first(where: {
        $0.provId == provId && $0.track == track && $0.year == year
            && (normalizeUniName($0.uniName).contains(target) || target.contains(normalizeUniName($0.uniName)))
    })
}

/// 某校某年某科类的专业级录取线（按最低分降序）
func findMajorAdmissions(
    _ ds: OfficialDataset, _ uniName: String, _ provId: String, _ track: Track, _ year: Int
) -> [OfficialMajorAdmission] {
    let target = normalizeUniName(uniName)
    return ds.majorAdmissions
        .filter { $0.provId == provId && $0.track == track && $0.year == year && normalizeUniName($0.uniName) == target }
        .sorted { $0.score > $1.score }
}

func findEmployment(_ ds: OfficialDataset, _ uniName: String) -> OfficialEmployment? {
    let target = normalizeUniName(uniName)
    if let exact = ds.employments.first(where: { normalizeUniName($0.uniName) == target }) { return exact }
    return ds.employments.first(where: {
        normalizeUniName($0.uniName).contains(target) || target.contains(normalizeUniName($0.uniName))
    })
}

// MARK: - 真实一分一段换算

/// 分数 -> 位次（线性插值）
func scoreToRank(_ t: RankTable, _ score: Double) -> Double? {
    let p = t.points
    guard !p.isEmpty else { return nil }
    if score >= p[0].score { return p[0].rank }
    if score <= p[p.count - 1].score { return p[p.count - 1].rank }
    for i in 1..<p.count where score >= p[i].score {
        let hi = p[i - 1], lo = p[i]
        let k = (score - lo.score) / ((hi.score - lo.score) == 0 ? 1 : (hi.score - lo.score))
        return jsRound(lo.rank + (hi.rank - lo.rank) * k)
    }
    return p[p.count - 1].rank
}

/// 位次 -> 分数（反向插值）
func rankToScore(_ t: RankTable, _ rank: Double) -> Double? {
    let p = t.points
    guard !p.isEmpty else { return nil }
    if rank <= p[0].rank { return p[0].score }
    if rank >= p[p.count - 1].rank { return p[p.count - 1].score }
    for i in 1..<p.count where rank <= p[i].rank {
        let hi = p[i - 1], lo = p[i]
        let k = (rank - hi.rank) / ((lo.rank - hi.rank) == 0 ? 1 : (lo.rank - hi.rank))
        return (hi.score + (lo.score - hi.score) * k)
    }
    return p[p.count - 1].score
}

// MARK: - 导入

struct ImportReport {
    var ok: Bool
    var rows: Int
    var messages: [String]
}

/// 解析一分一段表（列：分数、位次；可选省份 / 年份 / 科类）
func parseRankTableCsv(_ text: String, ctx: ImportContext) -> ParseResult<RankTable> {
    let rows = parseCsv(text)
    var warnings: [String] = []
    guard rows.count >= 2 else { return ParseResult(data: [], rows: 0, warnings: ["内容不足两行，无法解析"]) }

    let header = hasHeader(rows)
    let body = header ? Array(rows.dropFirst()) : rows
    let hs = header ? rows[0] : []
    let iScore = header ? findColumn(hs, .score) : 0
    let iRank = header ? findColumn(hs, .rank) : 1
    let iProv = header ? findColumn(hs, .prov) : -1
    let iYear = header ? findColumn(hs, .year) : -1
    let iTrack = header ? findColumn(hs, .track) : -1

    guard iScore >= 0, iRank >= 0 else {
        return ParseResult(data: [], rows: 0, warnings: ["未找到「分数」或「位次」列，请检查表头"])
    }

    final class Group {
        var provId: String
        var year: Int
        var track: Track
        var points: [Double: Double] = [:]
        init(provId: String, year: Int, track: Track) {
            self.provId = provId
            self.year = year
            self.track = track
        }
    }
    var groups: [String: Group] = [:]
    var n = 0
    for r in body {
        guard let score = toNumber(r[exist: iScore]), let rank = toNumber(r[exist: iRank]) else { continue }
        let provId = normalizeProvince(iProv >= 0 ? r[exist: iProv] : "", fallback: ctx.provId)
        let year = Int(toNumber(iYear >= 0 ? r[exist: iYear] : "") ?? Double(ctx.year))
        let track = normalizeTrack(iTrack >= 0 ? r[exist: iTrack] : "", fallback: ctx.track)
        let key = "\(provId)|\(year)|\(track.rawValue)"
        let g = groups[key] ?? Group(provId: provId, year: year, track: track)
        groups[key] = g
        if let prev = g.points[score] {
            if rank < prev { g.points[score] = rank }
        } else {
            g.points[score] = rank
        }
        n += 1
    }

    var data: [RankTable] = []
    for g in groups.values {
        var points = g.points.map { RankPoint(score: $0.key, rank: $0.value) }.sorted { $0.score > $1.score }
        guard points.count >= 2 else {
            warnings.append("\(g.provId)/\(g.year) 有效行数不足 2 行，已忽略")
            continue
        }
        for i in 1..<points.count where points[i].rank < points[i - 1].rank {
            points[i].rank = points[i - 1].rank
        }
        data.append(RankTable(provId: g.provId, year: g.year, track: g.track, points: points))
    }
    if data.isEmpty && warnings.isEmpty { warnings.append("未解析到有效数据") }
    return ParseResult(data: data, rows: n, warnings: warnings)
}

/// 解析院校投档线（列：院校、分数；可选位次/计划/省份/年份/科类）
func parseAdmissionCsv(_ text: String, ctx: ImportContext) -> ParseResult<OfficialAdmission> {
    let rows = parseCsv(text)
    var warnings: [String] = []
    guard rows.count >= 2 else { return ParseResult(data: [], rows: 0, warnings: ["内容不足两行，无法解析"]) }
    let header = hasHeader(rows)
    let body = header ? Array(rows.dropFirst()) : rows
    let hs = header ? rows[0] : []
    let iUni = header ? findColumn(hs, .uni) : 0
    let iScore = header ? findColumn(hs, .score) : 1
    let iRank = header ? findColumn(hs, .rank) : -1
    let iPlan = header ? findColumn(hs, .plan) : -1
    let iProv = header ? findColumn(hs, .prov) : -1
    let iYear = header ? findColumn(hs, .year) : -1
    let iTrack = header ? findColumn(hs, .track) : -1
    guard iUni >= 0, iScore >= 0 else {
        return ParseResult(data: [], rows: 0, warnings: ["未找到「院校名称」或「分数」列，请检查表头"])
    }

    var data: [OfficialAdmission] = []
    var seen = Set<String>()
    var n = 0
    for r in body {
        let name = r[exist: iUni].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let score = toNumber(r[exist: iScore]) else { continue }
        let provId = normalizeProvince(iProv >= 0 ? r[exist: iProv] : "", fallback: ctx.provId)
        let year = Int(toNumber(iYear >= 0 ? r[exist: iYear] : "") ?? Double(ctx.year))
        let track = normalizeTrack(iTrack >= 0 ? r[exist: iTrack] : "", fallback: ctx.track)
        let rank = iRank >= 0 ? toNumber(r[exist: iRank]) : nil
        let plan = iPlan >= 0 ? toNumber(r[exist: iPlan]) : nil
        let key = "\(provId)|\(track.rawValue)|\(year)|\(normalizeUniName(name))"
        if seen.contains(key) { continue }
        seen.insert(key)
        data.append(OfficialAdmission(uniName: name, provId: provId, track: track, year: year, score: score, rank: rank, plan: plan))
        n += 1
    }
    if data.isEmpty { warnings.append("未解析到有效数据") }
    return ParseResult(data: data, rows: n, warnings: warnings)
}

func importRankCsv(_ text: String, ctx: ImportContext, into ds: inout OfficialDataset) -> ImportReport {
    let res = parseRankTableCsv(text, ctx: ctx)
    guard !res.data.isEmpty else {
        return ImportReport(ok: false, rows: 0, messages: res.warnings.isEmpty ? ["未解析到有效数据"] : res.warnings)
    }
    let incoming = res.data
    ds.rankTables.removeAll { t in incoming.contains { $0.provId == t.provId && $0.year == t.year && $0.track == t.track } }
    ds.rankTables.append(contentsOf: incoming)
    ds.updatedAt = Date().timeIntervalSince1970 * 1000
    let msgs = incoming.map { "\($0.provId)/\($0.year)/\($0.track.label)：\($0.points.count) 个分数点" }
    return ImportReport(ok: true, rows: res.rows, messages: msgs + res.warnings)
}

func importAdmissionCsv(_ text: String, ctx: ImportContext, into ds: inout OfficialDataset) -> ImportReport {
    let res = parseAdmissionCsv(text, ctx: ctx)
    guard !res.data.isEmpty else {
        return ImportReport(ok: false, rows: 0, messages: res.warnings.isEmpty ? ["未解析到有效数据"] : res.warnings)
    }
    let incoming = res.data
    ds.admissions.removeAll { a in
        incoming.contains { n in
            n.provId == a.provId && n.track == a.track && n.year == a.year
                && normalizeUniName(n.uniName) == normalizeUniName(a.uniName)
        }
    }
    ds.admissions.append(contentsOf: incoming)
    ds.updatedAt = Date().timeIntervalSince1970 * 1000
    let years = Set(incoming.map(\.year)).sorted()
    let provs = Array(Set(incoming.map(\.provId))).sorted()
    return ImportReport(
        ok: true, rows: res.rows,
        messages: ["已导入 \(incoming.count) 条投档线（\(provs.joined(separator: "/")) · \(years.map(String.init).joined(separator: "/")) 年）"] + res.warnings
    )
}

/// 解析专业级录取线（列：院校、专业、最低分；可选 位次 / 计划 / 选科要求 / 批次 / 省份 / 年份 / 科类）
func parseMajorAdmissionCsv(_ text: String, ctx: ImportContext) -> ParseResult<OfficialMajorAdmission> {
    let rows = parseCsv(text)
    var warnings: [String] = []
    guard rows.count >= 2 else { return ParseResult(data: [], rows: 0, warnings: ["内容不足两行，无法解析"]) }
    let header = hasHeader(rows)
    let body = header ? Array(rows.dropFirst()) : rows
    let hs = header ? rows[0] : []
    // 「选科要求」里含「选科」，会抢走科类列，先定位再排除
    let iSubject = header ? findColumn(hs, .subjectReq) : -1
    let taken: Set<Int> = iSubject >= 0 ? [iSubject] : []
    let iUni = header ? findColumnExcluding(hs, .uni, excluding: taken) : 0
    let iMajor = header ? findColumnExcluding(hs, .major, excluding: taken) : 1
    let iScore = header ? findColumnExcluding(hs, .score, excluding: taken) : 2
    let iRank = header ? findColumnExcluding(hs, .rank, excluding: taken.union(iScore >= 0 ? [iScore] : [])) : -1
    let iPlan = header ? findColumnExcluding(hs, .plan, excluding: taken) : -1
    let iProv = header ? findColumnExcluding(hs, .prov, excluding: taken) : -1
    let iYear = header ? findColumnExcluding(hs, .year, excluding: taken) : -1
    let iTrack = header ? findColumnExcluding(hs, .track, excluding: taken) : -1
    guard iUni >= 0, iMajor >= 0, iScore >= 0 else {
        return ParseResult(data: [], rows: 0, warnings: ["未找到「院校名称 / 专业名称 / 最低分」列，请检查表头"])
    }

    var data: [OfficialMajorAdmission] = []
    var seen = Set<String>()
    var n = 0
    for r in body {
        let uni = r[exist: iUni].trimmingCharacters(in: .whitespaces)
        let major = r[exist: iMajor].trimmingCharacters(in: .whitespaces)
        guard !uni.isEmpty, !major.isEmpty, let score = toNumber(r[exist: iScore]) else { continue }
        let provId = normalizeProvince(iProv >= 0 ? r[exist: iProv] : "", fallback: ctx.provId)
        let year = Int(toNumber(iYear >= 0 ? r[exist: iYear] : "") ?? Double(ctx.year))
        let track = normalizeTrack(iTrack >= 0 ? r[exist: iTrack] : "", fallback: ctx.track)
        let key = "\(provId)|\(track.rawValue)|\(year)|\(normalizeUniName(uni))|\(major)"
        if seen.contains(key) { continue }
        seen.insert(key)
        data.append(
            OfficialMajorAdmission(
                uniName: uni, provId: provId, track: track, year: year, majorName: major,
                score: score,
                rank: iRank >= 0 ? toNumber(r[exist: iRank]) : nil,
                plan: iPlan >= 0 ? toNumber(r[exist: iPlan]) : nil,
                subjectReq: iSubject >= 0 ? r[exist: iSubject].trimmingCharacters(in: .whitespaces) : nil,
                batch: nil
            )
        )
        n += 1
    }
    if data.isEmpty { warnings.append("未解析到有效数据") }
    return ParseResult(data: data, rows: n, warnings: warnings)
}

func importMajorAdmissionCsv(_ text: String, ctx: ImportContext, into ds: inout OfficialDataset) -> ImportReport {
    let res = parseMajorAdmissionCsv(text, ctx: ctx)
    guard !res.data.isEmpty else {
        return ImportReport(ok: false, rows: 0, messages: res.warnings.isEmpty ? ["未解析到有效数据"] : res.warnings)
    }
    let incoming = res.data
    ds.majorAdmissions.removeAll { m in
        incoming.contains { n in
            n.provId == m.provId && n.track == m.track && n.year == m.year
                && normalizeUniName(n.uniName) == normalizeUniName(m.uniName) && n.majorName == m.majorName
        }
    }
    ds.majorAdmissions.append(contentsOf: incoming)
    ds.updatedAt = Date().timeIntervalSince1970 * 1000
    let withReq = incoming.filter { !($0.subjectReq ?? "").isEmpty }.count
    return ImportReport(
        ok: true, rows: res.rows,
        messages: ["已导入 \(incoming.count) 条专业录取线，其中 \(withReq) 条带选科要求"] + res.warnings
    )
}

func importEmploymentCsv(_ text: String, into ds: inout OfficialDataset) -> ImportReport {
    let rows = parseCsv(text)
    var warnings: [String] = []
    guard rows.count >= 2 else { return ImportReport(ok: false, rows: 0, messages: ["内容不足两行，无法解析"]) }
    let header = hasHeader(rows)
    let body = header ? Array(rows.dropFirst()) : rows
    let hs = header ? rows[0] : []
    let iUni = header ? findColumn(hs, .uni) : 0
    let iEmploy = header ? findColumn(hs, .employ) : 1
    let iFurther = header ? findColumn(hs, .further) : 2
    let iSalary = header ? findColumn(hs, .salary) : 3
    let iIndustry = header ? findColumn(hs, .industry) : -1
    let iYear = header ? findColumn(hs, .year) : -1
    guard iUni >= 0 else { return ImportReport(ok: false, rows: 0, messages: ["未找到「院校名称」列，请检查表头"]) }

    var data: [OfficialEmployment] = []
    for r in body {
        let uniName = r[exist: iUni].trimmingCharacters(in: .whitespaces)
        guard !uniName.isEmpty else { continue }
        let employ = iEmploy >= 0 ? toNumber(r[exist: iEmploy]) : nil
        let further = iFurther >= 0 ? toNumber(r[exist: iFurther]) : nil
        let salary = iSalary >= 0 ? toNumber(r[exist: iSalary]) : nil
        guard employ != nil || further != nil || salary != nil else { continue }
        let industries = iIndustry >= 0
            ? r[exist: iIndustry].components(separatedBy: CharacterSet(charactersIn: "、,，/|")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            : nil
        data.append(
            OfficialEmployment(
                uniName: uniName,
                year: iYear >= 0 ? toNumber(r[exist: iYear]) : nil,
                employRate: employ.map(clampPct),
                furtherRate: further.map(clampPct),
                salary: salary.map { jsRound($0) },
                industries: industries?.isEmpty == false ? Array(industries!.prefix(4)) : nil
            )
        )
    }
    guard !data.isEmpty else {
        return ImportReport(ok: false, rows: 0, messages: ["未解析到有效数据，请至少提供就业率 / 深造率 / 月薪 中的一项"])
    }
    ds.employments.removeAll { e in data.contains { normalizeUniName($0.uniName) == normalizeUniName(e.uniName) } }
    ds.employments.append(contentsOf: data)
    ds.updatedAt = Date().timeIntervalSince1970 * 1000
    let matched = data.filter { d in
        DataStore.shared.seeds.contains { normalizeUniName($0.name) == normalizeUniName(d.uniName) }
    }.count
    var msgs = ["已导入 \(data.count) 所院校的就业质量报告数据，其中 \(matched) 所与院校库名称匹配"]
    if data.count - matched > 0 { msgs.append("未匹配的院校名称请与院校库保持一致") }
    return ImportReport(ok: true, rows: data.count, messages: msgs + warnings)
}

private func clampPct(_ v: Double) -> Double {
    if v > 0 && v <= 1 { return (v * 100).rounded(toPlaces: 1) }
    return Swift.max(1, Swift.min(100, v)).rounded(toPlaces: 1)
}

struct DatasetStats {
    var tables: Int
    var points: Int
    var admissions: Int
    var years: [Int]
    var provinces: [String]
    var unis: Int
    var employments: Int
    var majors: Int
}

func datasetStats(_ ds: OfficialDataset) -> DatasetStats {
    let years = Array(Set(ds.rankTables.map(\.year) + ds.admissions.map(\.year) + ds.majorAdmissions.map(\.year))).sorted()
    let provs = Array(Set(ds.rankTables.map(\.provId) + ds.admissions.map(\.provId) + ds.majorAdmissions.map(\.provId))).sorted()
    return DatasetStats(
        tables: ds.rankTables.count,
        points: ds.rankTables.reduce(0) { $0 + $1.points.count },
        admissions: ds.admissions.count,
        years: years,
        provinces: provs,
        unis: Set(ds.admissions.map { normalizeUniName($0.uniName) }).count,
        employments: ds.employments.count,
        majors: ds.majorAdmissions.count
    )
}

extension Array where Element == String {
    /// 安全下标：越界返回空串，便于按列取值
    subscript(exist index: Int) -> String {
        guard index >= 0, index < count else { return "" }
        return self[index]
    }
}
