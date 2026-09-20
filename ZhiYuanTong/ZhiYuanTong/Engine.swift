import Foundation

/**
 * 录取模型核心（与 Web 版算法完全一致）：
 * 1) 用「线差（考生分数 - 当年特殊类型线）」作为跨年份可比的核心指标；
 * 2) 用「位次」做二次校验，并把往年位次换算成今年的等效分；
 * 3) 综合线差法与位次法给出录取概率与冲/稳/保分层。
 */

struct CurrentLines {
    var special: Double
    var undergrad: Double
    var college: Double
}

struct ProvinceTrendPoint: Identifiable {
    var year: Int
    var special: Double
    var undergrad: Double
    var onlineRate: Double
    var admitRate: Double
    var specialRate: Double
    var candidates: Double

    var id: Int { year }
}

struct Evaluated: Identifiable {
    let rec: UniversityRecord
    let prob: Double
    let tier: String
    /// 考生分数与该校今年等效分之差
    let gap: Double
    /// 位次差（负代表考生更靠前）
    let rankGap: Double

    var id: String { rec.seed.name }
}

final class AdmissionEngine {
    let store: DataStore
    /// 当前生效的官方数据集：有一分一段表时位次换算走真实数据
    var dataset: OfficialDataset

    init(store: DataStore = .shared, dataset: OfficialDataset = .empty) {
        self.store = store
        self.dataset = dataset
    }

    // MARK: - 基础换算

    func tableFor(_ prov: Province, _ year: Int, _ track: Track) -> RankTable? {
        dataset.rankTables.first { $0.provId == prov.id && $0.year == year && $0.track == track }
    }

    /// 该年该科类批次线（当年未公布时退回上一年）
    func linesOf(_ prov: Province, _ year: Int, _ track: Track) -> YearLines {
        prov.lines(year: year, track: track) ?? prov.lines(year: 2024, track: track)!
    }

    /// 科类考生数：3+3 为全体；3+1+2 按物理 62% / 历史 38% 拆分；老高考按理科 68% / 文科 32% 拆分
    func candidatesOf(_ prov: Province, _ year: Int, _ track: Track) -> Double {
        let total = linesOf(prov, year, track).candidates
        switch prov.mode {
        case .t33: return total
        case .old: return track == .phy ? total * 0.68 : total * 0.32
        case .t312: return track == .phy ? total * 0.62 : total * 0.38
        }
    }

    // MARK: - 位次经验曲线

    private static let rankAnchors: [(Double, Double)] = [
        (-320, 0.88), (-260, 0.79), (-220, 0.72), (-180, 0.64), (-150, 0.56), (-115, 0.4709),
        (-101, 0.4413), (-81, 0.3855), (-61, 0.3262), (-41, 0.2669), (-21, 0.2076), (0, 0.1542),
        (19, 0.1127), (39, 0.0795), (59, 0.0534), (79, 0.0356), (99, 0.0225), (119, 0.0135),
        (139, 0.0075), (159, 0.0035), (179, 0.0008), (199, 0.00025), (210, 0.0001),
    ]
    private static let logAnchors: [(Double, Double)] = rankAnchors.map { ($0.0, log($0.1)) }

    func rankFraction(_ over: Double) -> Double {
        let a = Self.logAnchors
        let n = a.count
        if over <= a[0].0 {
            let (x0, y0) = a[0]
            let (x1, y1) = a[1]
            return exp(y0 + ((over - x0) * (y1 - y0)) / (x1 - x0))
        }
        if over >= a[n - 1].0 {
            let (x0, y0) = a[n - 2]
            let (x1, y1) = a[n - 1]
            return exp(y0 + ((over - x0) * (y1 - y0)) / (x1 - x0))
        }
        for i in 0..<(n - 1) where over <= a[i + 1].0 {
            let (x0, y0) = a[i]
            let (x1, y1) = a[i + 1]
            return exp(y0 + ((over - x0) * (y1 - y0)) / (x1 - x0))
        }
        return exp(a[n - 1].1)
    }

    func rankOfScore(_ prov: Province, _ year: Int, _ track: Track, _ score: Double) -> Double {
        if let t = tableFor(prov, year, track), let r = scoreToRank(t, score) {
            return clamp(r, 1, jsRound(candidatesOf(prov, year, track) * 10000))
        }
        let total = candidatesOf(prov, year, track) * 10000
        return clamp(jsRound(rankFraction(score - linesOf(prov, year, track).special) * total), 1, jsRound(total))
    }

    func scoreOfRank(_ prov: Province, _ year: Int, _ track: Track, _ rank: Double) -> Double {
        if let t = tableFor(prov, year, track), let s = rankToScore(t, rank) { return s }
        return linesOf(prov, year, track).special + overFromRankCurve(prov, year, track, rank)
    }

    func rankFromOver(_ prov: Province, _ year: Int, _ track: Track, _ over: Double) -> Double {
        rankOfScore(prov, year, track, linesOf(prov, year, track).special + over)
    }

    func overFromRank(_ prov: Province, _ year: Int, _ track: Track, _ rank: Double) -> Double {
        if let t = tableFor(prov, year, track), let s = rankToScore(t, rank) {
            return s - linesOf(prov, year, track).special
        }
        return overFromRankCurve(prov, year, track, rank)
    }

    private func overFromRankCurve(_ prov: Province, _ year: Int, _ track: Track, _ rank: Double) -> Double {
        let total = candidatesOf(prov, year, track) * 10000
        let frac = clamp(rank / total, 1e-6, 0.99)
        let l = log(frac)
        let a = Self.logAnchors
        for i in 0..<(a.count - 1) {
            let (x0, y0) = a[i]
            let (x1, y1) = a[i + 1]
            if l >= y1 && l <= y0 {
                return x0 + ((l - y0) / (y1 - y0)) * (x1 - x0)
            }
        }
        return l > a[0].1 ? -320 : 200
    }

    // MARK: - 院校三年录取数据

    private static let levelPlan: [String: Double] = [
        "顶尖985": 38, "985": 110, "211": 150, "双一流": 70, "省重点": 240, "普通本科": 360, "民办/独立学院": 460,
    ]

    private func buildYearAdmission(
        _ seed: UniversitySeed, _ prov: Province, _ track: Track, _ year: Int, _ base: Double
    ) -> YearAdmission {
        let lines = linesOf(prov, year, track)
        let rnd = seeded("\(seed.name)|\(prov.id)|\(track.rawValue)|\(year)")
        let r1 = rnd(), r2 = rnd(), r3 = rnd(), r4 = rnd()

        let inProvince = seed.prov == prov.id
        let yearShift: Double
        switch year {
        case 2022: yearShift = -1.5
        case 2023: yearShift = 0.5
        default: yearShift = 1.2
        }
        let slope = (r1 - 0.45) * 6
        let drift = Double(year - 2022) * slope
        let noise = (r2 - 0.5) * 7

        let scale = clamp(lines.candidates / 70, 0.35, 2.2)
        let plan0 = Swift.max(
            4,
            jsRound((Self.levelPlan[seed.level] ?? 200) * scale * (inProvince ? 3.4 : 1) * (0.6 + 0.9 * r3))
        )

        if let official = findAdmission(dataset, seed.name, prov.id, track, year) {
            let score = jsRound(clamp(official.score, lines.college, 750))
            let realDiff = score - lines.special
            let rank = official.rank ?? rankOfScore(prov, year, track, score)
            let plan = official.plan ?? plan0
            let pressure = 1.05 + 0.85 * r4 + Swift.max(0, slope) / 14
            let applicants = jsRound(plan * pressure)
            return YearAdmission(
                year: year, score: score, rank: rank, diff: realDiff, plan: plan,
                applicants: applicants, admitRate: clamp(plan / applicants, 0.05, 0.98), official: true
            )
        }

        let diff = base + store.heat(of: seed.city) + (inProvince ? -10 : 0) + yearShift + drift + noise
        let score = jsRound(clamp(lines.special + diff, lines.college, 750))
        let realDiff = score - lines.special
        let rank = rankFromOver(prov, year, track, realDiff)
        let pressure = 1.05 + 0.85 * r4 + Swift.max(0, slope) / 14
        let applicants = jsRound(plan0 * pressure)
        let admitRate = clamp(plan0 / applicants, 0.05, 0.98)
        return YearAdmission(
            year: year, score: score, rank: rank, diff: realDiff, plan: plan0,
            applicants: applicants, admitRate: admitRate, official: nil
        )
    }

    func currentLines(_ prov: Province, _ track: Track, override: CurrentLines? = nil) -> CurrentLines {
        let l = prov.lines(year: store.currentYear, track: track) ?? prov.lines(year: 2024, track: track)!
        return CurrentLines(
            special: override?.special ?? l.special,
            undergrad: override?.undergrad ?? l.undergrad,
            college: override?.college ?? l.college
        )
    }

    func buildRecords(provId: String, track: Track) -> [UniversityRecord] {
        let prov = store.province(provId)
        let cur = currentLines(prov, track)
        var records: [UniversityRecord] = []
        for seed in store.seeds {
            let base = track == .phy ? seed.base : (seed.baseHis ?? seed.base - 6)
            let years = store.historyYears.map { buildYearAdmission(seed, prov, track, $0, base) }
            let diffs = years.map(\.diff)
            let avgDiff = mean(diffs)
            let avgRank = jsRound(mean(years.map(\.rank)))
            let avgScore = jsRound(mean(years.map(\.score)))
            let volatility = std(diffs)
            let delta3 = diffs[diffs.count - 1] - diffs[0]
            let equivScore = jsRound(cur.special + overFromRank(prov, store.currentYear, track, avgRank))
            records.append(
                UniversityRecord(
                    seed: seed, provId: provId, track: track, years: years,
                    avgScore: avgScore, avgDiff: avgDiff, avgRank: avgRank,
                    volatility: volatility, delta3: delta3,
                    heat: clamp(jsRound(52 + delta3 * 3.6 + volatility * 1.4), 0, 100),
                    equivScore: equivScore,
                    inProvince: seed.prov == prov.id,
                    officialYears: years.filter { $0.official == true }.count
                )
            )
        }
        return records
    }

    // MARK: - 录取概率评估

    private func sigmoid(_ x: Double) -> Double { 1 / (1 + exp(-x)) }

    /// 线差法 50% + 平均位次法 30% + 最低位次摸高 20%
    func evaluateUni(_ rec: UniversityRecord, studentScore: Double, studentRank: Double, curSpecial: Double) -> Evaluated {
        let studentDiff = studentScore - curSpecial
        let z1 = (studentDiff - rec.avgDiff) / Swift.max(rec.volatility, 6)
        let p1 = sigmoid(1.35 * z1)
        let z2 = log(rec.avgRank / Swift.max(studentRank, 1)) / 0.55
        let p2 = sigmoid(1.25 * z2)
        let minRank = rec.years.map(\.rank).min() ?? rec.avgRank
        let p3 = sigmoid(1.1 * log(minRank / Swift.max(studentRank, 1)) / 0.55)
        let prob = clamp(0.5 * p1 + 0.3 * p2 + 0.2 * p3, 0.01, 0.97)
        let tier: String = prob >= 0.75 ? "保" : prob >= 0.45 ? "稳" : prob >= 0.18 ? "冲" : "险"
        return Evaluated(
            rec: rec, prob: prob, tier: tier,
            gap: studentScore - rec.equivScore, rankGap: studentRank - rec.avgRank
        )
    }

    // MARK: - 省份趋势

    func provinceTrend(_ prov: Province, _ track: Track, override: CurrentLines? = nil) -> [ProvinceTrendPoint] {
        let years = store.historyYears + [store.currentYear]
        return years.map { year in
            let base = prov.lines(year: year, track: track) ?? prov.lines(year: 2024, track: track)!
            let special = year == store.currentYear ? (override?.special ?? base.special) : base.special
            let undergrad = year == store.currentYear ? (override?.undergrad ?? base.undergrad) : base.undergrad
            let candidates = year == store.currentYear ? (override == nil ? base.candidates : base.candidates) : base.candidates
            let ugPlan = base.ugPlan
            let total = candidatesOf(prov, year, track) * 10000
            let specialRate = rankFromOver(prov, year, track, 0) / total
            let admitRate = ugPlan / base.candidates
            let onlineRate = Swift.min(0.96, admitRate * 1.35)
            return ProvinceTrendPoint(
                year: year, special: special, undergrad: undergrad,
                onlineRate: (onlineRate * 100).rounded(toPlaces: 1),
                admitRate: (admitRate * 100).rounded(toPlaces: 1),
                specialRate: (specialRate * 100).rounded(toPlaces: 1),
                candidates: candidates
            )
        }
    }

    func batchOf(_ score: Double, _ cur: CurrentLines) -> String {
        if score >= cur.special { return "特殊类型线以上" }
        if score >= cur.undergrad { return "本科线上" }
        if score >= cur.college { return "专科线上" }
        return "专科线下"
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
