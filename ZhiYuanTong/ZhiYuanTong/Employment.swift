import Foundation

/**
 * 院校级就业预测模型（与 Web 版口径一致）：
 * 就业率 / 深造率由「院校层次 + 所在城市 + 王牌专业的全国中位数」推导，
 * 薪资按「专业中位薪资 × 层次系数 × 城市系数」估算；
 * 若导入了该校官方就业质量报告，则直接采用官方值（official = true）。
 */

struct MixItem: Identifiable, Hashable {
    var name: String
    var pct: Double
    var id: String { name }
}

struct EmploymentForecast {
    var uniName: String
    var employRate: Double
    var furtherRate: Double
    var domesticRate: Double
    var overseasRate: Double
    var flexRate: Double
    var salaryLo: Double
    var salaryHi: Double
    var salaryMid: Double
    var salary5y: Double
    var prosperity: Double
    var trend: String
    var industries: [MixItem]
    var employers: [MixItem]
    var cities: [MixItem]
    var majorProfiles: [MajorProfile]
    var relatedRate: Double
    var furtherImportant: Bool
    var peerPercentile: Double
    var highlights: [String]
    var risks: [String]
    var official: Bool
}

enum EmploymentModel {
    struct LevelFactor {
        var employ: Double
        var further: Double
        var salary: Double
        var institution: Double
        var base: Double
    }

    static let levelFactor: [String: LevelFactor] = [
        "顶尖985": .init(employ: 1.6, further: 1.25, salary: 1.2, institution: 1.08, base: 92),
        "985": .init(employ: 1.2, further: 1.14, salary: 1.13, institution: 1.04, base: 86),
        "211": .init(employ: 0.8, further: 1.04, salary: 1.07, institution: 1.0, base: 78),
        "双一流": .init(employ: 0.5, further: 1.0, salary: 1.03, institution: 0.96, base: 74),
        "省重点": .init(employ: 0, further: 0.95, salary: 1.0, institution: 0.92, base: 68),
        "普通本科": .init(employ: -0.9, further: 0.86, salary: 0.96, institution: 0.88, base: 62),
        "民办/独立学院": .init(employ: -2, further: 0.7, salary: 0.92, institution: 0.78, base: 55),
    ]

    static let kindIndustry: [String: [(String, Double)]] = [
        "综合": [("信息技术", 22), ("教育科研", 14), ("金融保险", 12), ("先进制造", 12), ("公共管理", 10), ("医疗与卫生", 8), ("文化传媒", 8)],
        "理工": [("信息技术", 26), ("先进制造", 20), ("半导体与电子", 12), ("能源电力", 10), ("建筑与基建", 10), ("科研与技术服务业", 12), ("国防军工与航空航天", 6)],
        "师范": [("基础教育", 48), ("公共管理", 10), ("文化传媒", 8), ("信息技术", 8), ("教育培训", 12)],
        "财经": [("金融保险", 24), ("会计与专业服务", 18), ("信息技术", 10), ("批发零售与电商", 10), ("先进制造", 10), ("公共管理", 12), ("房地产", 6)],
        "政法": [("政法机关与公共管理", 34), ("法律服务业", 24), ("金融保险", 10), ("企业合规与风控", 12), ("教育科研", 8)],
        "医药": [("医疗与卫生", 62), ("医疗器械", 10), ("生物医药", 8), ("公共管理", 8), ("科研与技术服务业", 6), ("医药流通", 6)],
        "农林": [("农林牧渔", 30), ("食品加工", 14), ("公共管理", 12), ("生物技术", 10), ("生态环保", 8), ("科研与技术服务业", 10)],
        "语言": [("跨境电商与外贸", 18), ("教育科研", 18), ("文化传媒", 14), ("信息技术", 10), ("旅游会展", 8), ("公共管理", 10), ("金融保险", 8)],
        "艺术": [("文化传媒与娱乐", 42), ("设计服务", 16), ("教育科研", 12), ("信息技术", 10), ("广告会展", 10)],
        "军工": [("国防军工与航空航天", 38), ("先进制造", 18), ("信息技术", 14), ("科研与技术服务业", 12), ("能源电力", 8)],
    ]

    static let standardIndustry: Set<String> = {
        var s = Set<String>()
        for list in kindIndustry.values { for item in list { s.insert(item.0) } }
        s.formUnion(["物流与交通", "医药流通", "生物技术", "基础教育", "教育培训", "食品加工", "会计与专业服务", "批发零售与电商", "企业合规与风控"])
        return s
    }()

    /// 行业名称归一：同义/近义归并，避免「其他」虚高
    static let industryAlias: [([String], String)] = [
        (["互联网", "软件", "游戏", "影视", "数字文娱", "电商", "零售"], "信息技术"),
        (["金融科技", "银行", "保险", "券商", "基金", "投资", "财富"], "金融保险"),
        (["半导体", "集成电路", "芯片", "电子", "光电", "显示", "面板"], "半导体与电子"),
        (["医疗器械", "医疗影像", "IVD", "医学装备", "手术机器人"], "医疗器械"),
        (["医院", "医疗", "卫生", "临床"], "医疗与卫生"),
        (["智能汽车", "汽车", "车辆", "整车", "新能源", "电池", "储能", "光伏", "锂电"], "先进制造"),
        (["智能制造", "装备制造", "机械", "制造", "工业软件", "锂电", "家电", "消费电子"], "先进制造"),
        (["建筑", "基建", "施工", "设计院", "房地产", "地产", "装饰", "景观"], "建筑与基建"),
        (["科研", "院所", "航天", "航空", "无人机", "测绘", "遥感"], "科研与技术服务业"),
        (["国防", "军工", "兵器", "船舶"], "国防军工与航空航天"),
        (["教育", "学校", "教师", "培训", "心理", "文博"], "教育科研"),
        (["金融保险", "金融"], "金融保险"),
        (["公共管理", "党政机关", "政府", "国防", "政法", "机关", "事业单位", "公共服务", "社会工作", "社区"], "公共管理"),
        (["文化", "传媒", "广告", "会展", "出版", "艺术", "娱乐", "MCN", "设计服务", "动漫", "音乐", "舞蹈"], "文化传媒"),
        (["能源", "电力", "电网", "石油", "核"], "能源电力"),
        (["化工", "材料", "石化", "新材料", "冶金", "纺织", "轻工", "食品", "制药", "生物医药", "生物技术", "生物"], "先进制造"),
        (["物流", "交通运输", "交通", "航运", "快递", "供应链"], "物流与交通"),
        (["农林", "牧渔", "农业", "种植", "养殖", "园艺", "林业", "动物", "宠物", "水产", "食品"], "农林牧渔"),
        (["环保", "环境", "生态", "双碳", "水务", "碳汇"], "生态环保"),
        (["法律", "律师", "律所", "知识产权", "专利", "合规", "风控"], "法律服务业"),
        (["外贸", "跨境电商", "出海", "国际物流", "外企"], "跨境电商与外贸"),
    ]

    static let kindEmployer: [String: [(String, Double)]] = [
        "综合": [("民营企业", 40), ("国有企业", 22), ("机关事业单位", 12), ("外资企业", 10), ("灵活就业/创业", 16)],
        "理工": [("民营企业", 46), ("国有企业", 22), ("外资企业", 14), ("机关事业单位", 8), ("灵活就业/创业", 10)],
        "师范": [("机关事业单位", 52), ("民营企业", 18), ("灵活就业/创业", 20), ("国有企业", 6), ("外资企业", 4)],
        "财经": [("民营企业", 42), ("国有企业", 20), ("机关事业单位", 14), ("外资企业", 12), ("灵活就业/创业", 12)],
        "政法": [("机关事业单位", 40), ("民营企业", 26), ("国有企业", 12), ("灵活就业/创业", 18), ("外资企业", 4)],
        "医药": [("机关事业单位", 58), ("民营企业", 18), ("外资企业", 8), ("国有企业", 8), ("灵活就业/创业", 8)],
        "农林": [("民营企业", 40), ("机关事业单位", 20), ("国有企业", 14), ("灵活就业/创业", 20), ("外资企业", 6)],
        "语言": [("民营企业", 44), ("机关事业单位", 16), ("外资企业", 12), ("灵活就业/创业", 20), ("国有企业", 8)],
        "艺术": [("民营企业", 50), ("灵活就业/创业", 26), ("机关事业单位", 10), ("国有企业", 8), ("外资企业", 6)],
        "军工": [("国有企业/科研院所", 56), ("民营企业", 18), ("机关事业单位", 14), ("外资企业", 4), ("灵活就业/创业", 8)],
    ]

    static let magnetCities = ["深圳", "上海", "北京", "杭州", "广州", "成都", "苏州", "南京", "武汉", "西安", "合肥", "长沙"]

    static let overseasShare: [String: Double] = [
        "顶尖985": 0.2, "985": 0.14, "211": 0.09, "双一流": 0.07,
        "省重点": 0.05, "普通本科": 0.03, "民办/独立学院": 0.03,
    ]

    static func aliasIndustry(_ name: String) -> String {
        if name.contains("其他") { return "其他" }
        if standardIndustry.contains(name) { return name }
        for (keys, std) in industryAlias where keys.contains(where: { name.contains($0) }) { return std }
        return name
    }

    static func trendScore(_ t: String) -> Double {
        t == "上升" ? 82 : t == "承压" ? 48 : 65
    }

    /// 王牌专业 -> 专业画像（顺序靠前权重更高）
    static func matchedMajors(_ seed: UniversitySeed) -> [(p: MajorProfile, w: Double)] {
        var out: [(p: MajorProfile, w: Double)] = []
        var seen = Set<String>()
        for (i, name) in seed.majors.enumerated() {
            guard let p = DataStore.shared.majorProfile(name), !seen.contains(p.name) else { continue }
            seen.insert(p.name)
            out.append((p, 1 / (Double(i) + 1.6)))
        }
        if out.isEmpty {
            let fallback: [String: String] = [
                "综合": "计算机科学与技术", "理工": "机械设计制造及其自动化", "师范": "汉语言文学",
                "财经": "金融学", "政法": "法学", "医药": "临床医学", "农林": "动物医学",
                "语言": "英语", "艺术": "视觉传达设计", "军工": "航空航天工程",
            ]
            if let p = DataStore.shared.majorProfile(fallback[seed.kind] ?? "") { out.append((p, 1)) }
        }
        let sum = out.reduce(0) { $0 + $1.w }
        return out.map { ($0.p, $0.w / (sum == 0 ? 1 : sum)) }
    }

    static func normalizeMix(_ list: [(name: String, w: Double)], top: Int = 6, alias: Bool = true) -> [MixItem] {
        var merged: [String: Double] = [:]
        for item in list {
            let key = alias ? aliasIndustry(item.name) : item.name
            merged[key, default: 0] += item.w
        }
        let arr = merged.sorted { $0.value > $1.value }
        let raw = arr.reduce(0) { $0 + $1.value }
        let total = raw == 0 ? 1 : raw
        var picked: [MixItem] = arr.prefix(top).map { MixItem(name: $0.key, pct: (($0.value / total) * 100).rounded(toPlaces: 1)) }
        let sum = picked.reduce(0) { $0 + $1.pct }
        let rest = (100 - sum).rounded(toPlaces: 1)
        if arr.count > top && rest > 0.5 {
            if let i = picked.firstIndex(where: { $0.name == "其他" }) {
                picked[i].pct = (picked[i].pct + rest).rounded(toPlaces: 1)
            } else {
                picked.append(MixItem(name: "其他", pct: rest))
            }
        } else if !picked.isEmpty {
            let idx = picked.indices.sorted { picked[$0].pct > picked[$1].pct }.first { picked[$0].name != "其他" } ?? 0
            picked[idx].pct = (picked[idx].pct + rest).rounded(toPlaces: 1)
        }
        return picked
    }

    static func cityMixOf(_ seed: UniversitySeed, _ majors: [(p: MajorProfile, w: Double)]) -> [MixItem] {
        let store = DataStore.shared
        let local = store.cityCareerMap[seed.city]
        let base: Double = seed.level == "顶尖985" ? 32 : seed.level == "985" ? 35
            : (seed.level == "211" || seed.level == "双一流") ? 38 : 42
        let power: Double = local == nil ? 1 : (local!.prosperity >= 72 ? 1.12 : local!.prosperity >= 65 ? 1 : 0.88)
        let localShare = clamp(jsRound(base * power), 18, 55)

        var weights: [String: Double] = [:]
        let isRealCity: (String) -> Bool = { c in
            c.count <= 4 && !["各", "省内", "本地", "一线", "海外", "矿区", "园区", "主产区", "林区", "项目"].contains(where: { c.contains($0) })
        }
        for m in majors {
            for (i, c) in m.p.cities.filter(isRealCity).enumerated() {
                weights[c, default: 0] += m.w * (4 - Double(Swift.min(i, 3)))
            }
        }
        for c in magnetCities { weights[c, default: 0] += 1.6 }
        weights.removeValue(forKey: seed.city)
        let pros = Dictionary(uniqueKeysWithValues: store.cityCareers.map { ($0.name, $0.prosperity) })
        let arr = weights.sorted { $0.value > $1.value }.prefix(5)
        let arrTotal = arr.reduce(0) { $0 + $1.value }
        let denom: Double = arrTotal == 0 ? 1 : arrTotal
        let rest = 100 - localShare
        var out: [MixItem] = [MixItem(name: seed.city, pct: localShare)]
        for (name, w) in arr {
            out.append(MixItem(name: name, pct: (w / denom) * rest * (1 + ((pros[name] ?? 70) - 70) / 100)))
        }
        let sum = out.reduce(0) { $0 + $1.pct }
        let s = sum == 0 ? 1 : sum
        return out.map { MixItem(name: $0.name, pct: (($0.pct / s) * 100).rounded(toPlaces: 1)) }
            .sorted { $0.pct > $1.pct }.prefix(6).map { $0 }
    }

    static func forecastOf(_ seed: UniversitySeed, _ ds: OfficialDataset? = nil) -> EmploymentForecast {
        let store = DataStore.shared
        let majors = matchedMajors(seed)
        let f = levelFactor[seed.level] ?? levelFactor["省重点"]!
        let city = store.cityCareerMap[seed.city]
        let cityProsperity = city?.prosperity ?? 68
        let citySalary = city?.salary ?? 8600

        let wEmploy = majors.reduce(0) { $0 + $1.w * $1.p.employRate }
        let wFurther = majors.reduce(0) { $0 + $1.w * $1.p.furtherRate }
        let wLo = majors.reduce(0) { $0 + $1.w * $1.p.salaryMin }
        let wHi = majors.reduce(0) { $0 + $1.w * $1.p.salaryMax }
        let wMid = majors.reduce(0) { $0 + $1.w * $1.p.mid5y }
        let wTrend = majors.reduce(0) { $0 + $1.w * trendScore($1.p.trend) }

        let official = ds.flatMap { findEmployment($0, seed.name) }
        let employRate = official?.employRate ?? clamp(0.5 * seed.employRate + 0.5 * wEmploy + f.employ + (cityProsperity - 70) * 0.06, 70, 99)
        let furtherRate = official?.furtherRate ?? clamp(0.62 * seed.further + 0.38 * wFurther * f.further + Swift.min(6, seed.baoyan * 0.35), 5, 92)
        let overseasRate = (furtherRate * (overseasShare[seed.level] ?? 0.03)).rounded(toPlaces: 1)
        let domesticRate = (furtherRate - overseasRate).rounded(toPlaces: 1)
        let flexRate = clamp(100 - employRate + 2, 1, 18).rounded(toPlaces: 1)

        let cityCoef = clamp(citySalary / 9200, 0.9, 1.15)
        let furtherBonus = 1 + (furtherRate - 40) / 500
        let salaryLo = official?.salary.map { jsRound($0 * 0.85) } ?? jsRound(wLo * f.salary * cityCoef)
        let salaryHi = official?.salary.map { jsRound($0 * 1.15) } ?? jsRound(wHi * f.salary * cityCoef * furtherBonus)
        let salaryMid = official?.salary.map { jsRound($0) } ?? jsRound(salaryLo + (salaryHi - salaryLo) * 0.32)
        let salary5y = official?.salary.map { jsRound($0 * 1.75) } ?? jsRound(wMid * f.salary * (0.8 + 0.2 * cityCoef))

        var industryList: [(name: String, w: Double)] = (kindIndustry[seed.kind] ?? []).map { (name: $0.0, w: $0.1) }
        if let oi = official?.industries {
            for (i, name) in oi.enumerated() { industryList.append((name, Double(26 - i * 4))) }
        }
        for m in majors {
            for (i, name) in m.p.industries.prefix(3).enumerated() {
                industryList.append((name, m.w * Double(20 - i * 5)))
            }
        }
        let industries = normalizeMix(industryList, top: 6, alias: true)

        let employerList = (kindEmployer[seed.kind] ?? []).map { (name: $0.0, w: $0.1) }
            .map { (name, w) -> (name: String, w: Double) in
                (name: name, w: name.contains("机关") || name.contains("国有") ? w * f.institution : w)
            }
        let employers = normalizeMix(employerList, top: 5, alias: false)
        let cities = cityMixOf(seed, majors)

        let prosperity = clamp(0.5 * wTrend + 0.25 * cityProsperity + 0.25 * f.base, 30, 98).rounded(toPlaces: 0)
        let up = majors.filter { $0.p.trend == "上升" }.reduce(0) { $0 + $1.w }
        let down = majors.filter { $0.p.trend == "承压" }.reduce(0) { $0 + $1.w }
        let trend: String = up - down > 0.18 ? "上升" : down - up > 0.18 ? "承压" : "平稳"
        let relatedRate = clamp(62 + (f.base - 68) * 0.35 + (seed.kind == "医药" || seed.kind == "师范" || seed.kind == "军工" ? 12 : 0), 45, 95)
            .rounded(toPlaces: 0)

        var highlights: [String] = []
        var risks: [String] = []
        if let o = official {
            let year = o.year.map { String(format: "%.0f 届", $0) } ?? ""
            highlights.append("已采用官方就业质量报告数据\(year.isEmpty ? "" : "（\(year)）")：落实率 \(String(format: "%.0f", employRate))%、月薪 \(Int(salaryMid)) 元")
        }
        if prosperity >= 78 { highlights.append("就业景气 \(Int(prosperity))，高于同层次院校平均，赛道与平台形成叠加优势") }
        else if prosperity <= 58 { risks.append("就业景气 \(Int(prosperity))，低于同层次院校平均，需要靠实习与技能补齐平台劣势") }
        if furtherRate >= 55 {
            highlights.append("深造率 \(String(format: "%.0f", furtherRate))%（国内 \(String(format: "%.0f", domesticRate))%、出国 \(String(format: "%.0f", overseasRate))%），适合作为读研跳板")
            if seed.baoyan >= 15 { highlights.append("保研率 \(Int(seed.baoyan))%，校内推免机会较多") }
        }
        if salary5y - salaryMid >= 9000 {
            highlights.append("薪资弹性大：应届 \(Int(salaryMid)) 元 → 5 年 \(Int(salary5y)) 元，经验溢价明显")
        }
        if seed.kind == "医药" && majors.contains(where: { $0.p.name == "临床医学" }) {
            risks.append("临床医学培养周期长（5+3），需评估家庭投入与规培城市")
        }
        let riskyMajors = majors.filter { $0.p.trend == "承压" }
        if !riskyMajors.isEmpty {
            risks.append("王牌专业中 \(riskyMajors.map(\.p.name).joined(separator: "、")) 当前招聘景气度偏弱，建议入学后尽早辅修或转方向")
        }
        if city == nil {
            risks.append("\(seed.city) 暂无本地产业景气数据，就业更多依赖外出，建议大一开始就到一线/新一线城市实习")
        } else if city!.prosperity < 66 {
            risks.append("\(seed.city) 本地产业景气偏低（\(Int(city!.prosperity))），建议大一开始就到一线/新一线城市实习")
        }
        if seed.level == "民办/独立学院" || seed.level == "普通本科" {
            risks.append("院校平台竞争力有限，就业更依赖个人证书、实习与项目经历，建议尽早规划考研或技能路线")
        }
        if trend == "承压" { risks.append("该校主力学科整体处于招聘收缩周期，志愿组内建议搭配景气上升方向的院校") }
        if risks.isEmpty { risks.append("暂无明显结构性风险，但仍建议关注目标行业周期与所在城市的落户政策") }

        return EmploymentForecast(
            uniName: seed.name,
            employRate: employRate.rounded(toPlaces: 1),
            furtherRate: furtherRate.rounded(toPlaces: 1),
            domesticRate: domesticRate, overseasRate: overseasRate, flexRate: flexRate,
            salaryLo: salaryLo, salaryHi: salaryHi, salaryMid: salaryMid, salary5y: salary5y,
            prosperity: prosperity, trend: trend,
            industries: industries, employers: employers, cities: cities,
            majorProfiles: majors.map(\.p),
            relatedRate: relatedRate,
            furtherImportant: furtherRate >= 50 || majors.contains(where: { $0.p.furtherRate >= 55 }),
            peerPercentile: 50,
            highlights: highlights, risks: risks, official: official != nil
        )
    }

    private static var cacheKey: String?
    private static var cache: [String: EmploymentForecast] = [:]

    /// 全部院校就业预测（带缓存，加载就业数据后自动重算）
    static func allForecasts(_ ds: OfficialDataset? = nil) -> [String: EmploymentForecast] {
        let key = (ds?.employments.isEmpty == false) ? "emp-\(ds!.employments.count)-\(Int(ds!.updatedAt))" : "base"
        if cacheKey == key { return cache }
        var map: [String: EmploymentForecast] = [:]
        for s in DataStore.shared.seeds { map[s.name] = forecastOf(s, ds) }

        var byLevel: [String: [String]] = [:]
        for s in DataStore.shared.seeds { byLevel[s.level, default: []].append(s.name) }
        for names in byLevel.values {
            let sorted = names.sorted { (map[$0]?.prosperity ?? 0) < (map[$1]?.prosperity ?? 0) }
            for (i, name) in sorted.enumerated() {
                let pct = sorted.count <= 1 ? 100.0 : Double(i) / Double(sorted.count - 1) * 100
                map[name]?.peerPercentile = pct.rounded()
            }
        }
        cache = map
        cacheKey = key
        return map
    }

    static func forecast(name: String, _ ds: OfficialDataset? = nil) -> EmploymentForecast? {
        allForecasts(ds)[name]
    }

    struct EmploymentAggregate {
        var count: Int
        var avgEmployRate: Double
        var avgFurtherRate: Double
        var avgSalary: Double
        var avgSalary5y: Double
        var prosperity: Double
        var industries: [MixItem]
        var cities: [MixItem]
        var concentration: Double
        var risingShare: Double
        var pressedShare: Double
        var notes: [String]
    }

    /// 志愿表的就业结构聚合
    static func aggregate(_ forecasts: [EmploymentForecast]) -> EmploymentAggregate? {
        guard !forecasts.isEmpty else { return nil }
        let n = Double(forecasts.count)
        let avg: ((EmploymentForecast) -> Double) -> Double = { fn in forecasts.reduce(0) { $0 + fn($1) } / n }

        let industryMix = normalizeMix(
            forecasts.flatMap { f in f.industries.filter { $0.name != "其他" }.map { (name: $0.name, w: $0.pct / n) } },
            top: 6
        )
        let cityMix = normalizeMix(
            forecasts.flatMap { f in f.cities.map { (name: $0.name, w: $0.pct / n) } },
            top: 6, alias: false
        )
        let hhi = industryMix.reduce(0) { $0 + pow($1.pct / 100, 2) }
        let rising = Double(forecasts.filter { $0.trend == "上升" }.count) / n
        let pressed = Double(forecasts.filter { $0.trend == "承压" }.count) / n

        var notes: [String] = []
        if let first = industryMix.first, first.pct >= 45 {
            notes.append("\(String(format: "%.0f", first.pct))% 的毕业去向集中在「\(first.name)」，行业周期波动时会同时承压，建议补充 2-3 个不同赛道的院校")
        }
        if pressed >= 0.4 { notes.append("\(String(format: "%.0f", pressed * 100))% 的志愿主力学科处于招聘收缩周期，建议增加景气上升方向的院校") }
        if rising >= 0.5 { notes.append("\(String(format: "%.0f", rising * 100))% 的志愿就业景气为上升，赛道结构健康") }
        let avgFurther = avg { $0.furtherRate }
        if avgFurther >= 55 { notes.append("这组院校整体深造率高，若计划本科就业，请重点确认目标专业的就业支持与实习资源") }
        let topCities = Array(cityMix.prefix(2))
        if let c = topCities.first, c.pct >= 50 {
            notes.append("就业地域高度集中在 \(c.name)，需确认是否接受在该城市长期发展")
        }
        if notes.isEmpty { notes.append("行业与地域分布较为分散，抗周期能力较好") }

        return EmploymentAggregate(
            count: forecasts.count,
            avgEmployRate: avg { $0.employRate }.rounded(toPlaces: 1),
            avgFurtherRate: avgFurther.rounded(toPlaces: 1),
            avgSalary: jsRound(avg { $0.salaryMid }),
            avgSalary5y: jsRound(avg { $0.salary5y }),
            prosperity: jsRound(avg { $0.prosperity }),
            industries: industryMix, cities: cityMix,
            concentration: jsRound(hhi * 100),
            risingShare: rising, pressedShare: pressed, notes: notes
        )
    }
}
