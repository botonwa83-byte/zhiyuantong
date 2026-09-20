import Foundation

// MARK: - 基础枚举

enum Track: String, Codable, CaseIterable, Identifiable {
    case phy
    case his

    var id: String { rawValue }
    var label: String { self == .phy ? "物理类" : "历史类" }
}

enum ExamMode: String, Codable {
    case t312 = "3+1+2"
    case t33 = "3+3"
    /// 老高考文理分科：新疆、西藏 2024 年秋高一才启动改革、2027 年首考，2022–2026 届仍是理科/文科
    case old = "文理分科"

    /// 未识别取值（老 bundle / 脏数据）退回 3+1+2，避免整份数据集解码失败
    init(from decoder: Decoder) throws {
        let v = try decoder.singleValueContainer().decode(String.self)
        self = ExamMode(rawValue: v) ?? .t312
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// 科类名称随考试模式变化：3+1+2 → 物理类/历史类；3+3 → 综合；文理分科 → 理科/文科
func trackLabel(_ track: Track, _ mode: ExamMode) -> String {
    switch mode {
    case .t312: return track == .phy ? "物理类" : "历史类"
    case .t33: return "综合"
    case .old: return track == .phy ? "理科" : "文科"
    }
}

struct YearLines: Codable {
    var special: Double      // 特殊类型招生控制线
    var undergrad: Double    // 本科批控制线
    var college: Double      // 专科批控制线
    var candidates: Double   // 报考人数（万人）
    var ugPlan: Double       // 本科招生计划（万人）
}

/// JSON 中的扁平分数线记录（year + track + 五个数）
struct ProvinceLine: Codable {
    var year: Int
    var track: Track
    var special: Double
    var undergrad: Double
    var college: Double
    var candidates: Double
    var ugPlan: Double

    var lines: YearLines {
        YearLines(special: special, undergrad: undergrad, college: college, candidates: candidates, ugPlan: ugPlan)
    }
}

struct ProvinceDTO: Codable {
    var id: String
    var name: String
    var mode: ExamMode
    var lines: [ProvinceLine]
}

struct Province: Identifiable {
    let id: String
    let name: String
    let mode: ExamMode
    private let table: [Int: [Track: YearLines]]

    init(dto: ProvinceDTO) {
        id = dto.id
        name = dto.name
        mode = dto.mode
        var t: [Int: [Track: YearLines]] = [:]
        for l in dto.lines {
            t[l.year, default: [:]][l.track] = l.lines
        }
        table = t
    }

    func lines(year: Int, track: Track) -> YearLines? { table[year]?[track] }
}

// MARK: - 院校

struct UniversitySeed: Codable, Identifiable {
    var name: String
    var prov: String
    var city: String
    var level: String
    var kind: String
    var base: Double
    var baseHis: Double?
    var strengths: [String]
    var majors: [String]
    var baoyan: Double
    var further: Double
    var employRate: Double
    var salary: Double
    var industries: [String]
    var employers: [String]

    var id: String { name }
}

struct YearAdmission: Codable, Identifiable {
    var year: Int
    var score: Double
    var rank: Double
    var diff: Double
    var plan: Double
    var applicants: Double
    var admitRate: Double
    var official: Bool?

    var id: Int { year }
}

struct UniversityRecord: Identifiable {
    let seed: UniversitySeed
    let provId: String
    let track: Track
    let years: [YearAdmission]
    let avgScore: Double
    let avgDiff: Double
    let avgRank: Double
    let volatility: Double
    let delta3: Double
    let heat: Double
    let equivScore: Double
    let inProvince: Bool
    let officialYears: Int

    var id: String { seed.name }
}

// MARK: - 考生与志愿

/// 智能生成志愿表的梯度策略：冲 / 稳 / 保 的分配倾向
enum GenStrategy: String, Codable, CaseIterable, Identifiable {
    case aggressive    // 冲刺
    case balanced      // 均衡
    case conservative  // 保守

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aggressive: return "冲刺"
        case .balanced: return "均衡"
        case .conservative: return "保守"
        }
    }

    var note: String {
        switch self {
        case .aggressive: return "多放高分校赌大小年，保底较薄"
        case .balanced: return "冲稳保比例最常用，梯度最健康"
        case .conservative: return "以稳保为主，优先不滑档"
        }
    }
}

struct StudentProfile: Codable, Identifiable {
    var id: String
    var phone: String
    var name: String
    var provId: String
    var track: Track
    var score: Double
    var rank: Double?
    var subjects: [String]
    var cities: [String]
    var majors: [String]
    var obeyAdjust: Bool
    var linesOverride: LinesOverride?
    var createdAt: Double
    /// 智能生成志愿表时的梯度策略
    var strategy: GenStrategy
    /// 智能生成志愿表时是否优先省内院校
    var preferProvince: Bool
    /// 智能生成志愿表时选中的热门专业（细分方向，区别于 majors 的学科门类）
    var hotMajors: [String]

    struct LinesOverride: Codable {
        var special: Double?
        var undergrad: Double?
        var college: Double?
    }
}

/// 老版本存档没有 strategy / preferProvince / hotMajors 三个键，这里给默认值，避免解码失败丢档案
extension StudentProfile {
    private enum CodingKeys: String, CodingKey {
        case id, phone, name, provId, track, score, rank, subjects, cities, majors
        case obeyAdjust, linesOverride, createdAt, strategy, preferProvince, hotMajors
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        phone = try c.decode(String.self, forKey: .phone)
        name = try c.decode(String.self, forKey: .name)
        provId = try c.decode(String.self, forKey: .provId)
        track = try c.decode(Track.self, forKey: .track)
        score = try c.decode(Double.self, forKey: .score)
        rank = try c.decodeIfPresent(Double.self, forKey: .rank)
        subjects = try c.decodeIfPresent([String].self, forKey: .subjects) ?? []
        cities = try c.decodeIfPresent([String].self, forKey: .cities) ?? []
        majors = try c.decodeIfPresent([String].self, forKey: .majors) ?? []
        obeyAdjust = try c.decode(Bool.self, forKey: .obeyAdjust)
        linesOverride = try c.decodeIfPresent(LinesOverride.self, forKey: .linesOverride)
        createdAt = try c.decode(Double.self, forKey: .createdAt)
        strategy = (try? c.decode(GenStrategy.self, forKey: .strategy)) ?? .balanced
        preferProvince = (try? c.decode(Bool.self, forKey: .preferProvince)) ?? true
        hotMajors = (try? c.decode([String].self, forKey: .hotMajors)) ?? []
    }
}

struct VolunteerItem: Codable, Identifiable {
    var uniName: String
    var tier: String
    var prob: Double
    var note: String?

    var id: String { uniName }
}

// MARK: - 就业与专业

struct MajorCareer: Codable, Identifiable {
    var name: String
    var directions: [String]
    var industries: [String]
    var employRate: Double
    var furtherRate: Double
    var salaryMin: Double
    var salaryMax: Double
    var midSalary: Double
    var trend: String
    var trendNote: String
    var advice: String

    var id: String { name }
}

struct HotMajor: Codable, Identifiable {
    var name: String
    var directions: [String]
    var industries: [String]
    var employRate: Double
    var furtherRate: Double
    var salaryMin: Double
    var salaryMax: Double
    var midSalary: Double
    var trend: String
    var trendNote: String
    var advice: String
    var schools: [String]
    var subjects: String

    var id: String { name }
}

struct MajorProfile: Codable, Identifiable {
    var name: String
    var discipline: String
    var employRate: Double
    var furtherRate: Double
    var salaryMin: Double
    var salaryMax: Double
    var mid5y: Double
    var trend: String
    var jobs: [String]
    var industries: [String]
    var cities: [String]
    var subjects: String
    var barrier: String
    var risk: String?

    var id: String { name }
}

struct CityCareer: Codable, Identifiable {
    var name: String
    var industries: [String]
    var salary: Double
    var cost: Double
    var settle: String
    var prosperity: Double
    var policy: String
    var note: String

    var id: String { name }
}

// MARK: - 资源包

struct DataBundle: Codable {
    var currentYear: Int
    var historyYears: [Int]
    var provinces: [ProvinceDTO]
    var universities: [UniversitySeed]
    var cityHeat: [String: Double]
    var majorProfiles: [MajorProfile]
    var majorCareers: [MajorCareer]
    var hotMajors: [HotMajor]
    var cityCareers: [CityCareer]
}
