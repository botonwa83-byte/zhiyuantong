import Foundation

struct Filters: Equatable {
    var keyword: String = ""
    var levels: [String] = []
    var kinds: [String] = []
    var cities: [String] = []
    var onlyInProvince = false
    /// 只看有把握的（概率 >= 45%）
    var safeOnly = false
    /// 隐藏基本不可能录取的院校（概率 < 8%）
    var hideHopeless = true
    /// 只看就业景气为「上升」的院校
    var risingOnly = false
    var sort: Sort = .score

    enum Sort: String, CaseIterable, Identifiable {
        case score, prob, rank, heat, employ
        var id: String { rawValue }
        var label: String {
            switch self {
            case .prob: return "录取率"
            case .score: return "等效分"
            case .rank: return "位次"
            case .heat: return "热度"
            case .employ: return "就业"
            }
        }
    }

    var activeCount: Int {
        levels.count + kinds.count + cities.count
            + (onlyInProvince ? 1 : 0) + (safeOnly ? 1 : 0) + (risingOnly ? 1 : 0) + (hideHopeless ? 0 : 1)
    }

    static var `default`: Filters { Filters() }
}

enum Recommend {
    static func filterAndSort(_ list: [Evaluated], _ f: Filters, _ ds: OfficialDataset? = nil) -> [Evaluated] {
        let kw = f.keyword.trimmingCharacters(in: .whitespaces)
        let out = list.filter { e in
            let s = e.rec.seed
            if !kw.isEmpty && !s.name.contains(kw) && !s.city.contains(kw) && !s.majors.contains(where: { $0.contains(kw) }) { return false }
            if !f.levels.isEmpty && !f.levels.contains(s.level) { return false }
            if !f.kinds.isEmpty && !f.kinds.contains(s.kind) { return false }
            if !f.cities.isEmpty && !f.cities.contains(s.city) { return false }
            if f.onlyInProvince && !e.rec.inProvince { return false }
            if f.safeOnly && e.prob < 0.45 { return false }
            if f.hideHopeless && e.prob < 0.08 { return false }
            if f.risingOnly && EmploymentModel.forecast(name: s.name, ds)?.trend != "上升" { return false }
            return true
        }
        return out.sorted { a, b in
            switch f.sort {
            case .prob: return a.prob > b.prob
            case .score: return a.rec.equivScore > b.rec.equivScore
            case .rank: return a.rec.avgRank < b.rec.avgRank
            case .heat: return a.rec.heat > b.rec.heat
            case .employ:
                let pa = EmploymentModel.forecast(name: a.rec.seed.name, ds)?.prosperity ?? 0
                let pb = EmploymentModel.forecast(name: b.rec.seed.name, ds)?.prosperity ?? 0
                return pa > pb
            }
        }
    }

    struct Advice: Identifiable {
        var title: String
        var text: String
        var tone: Tone
        enum Tone { case info, warn, good }
        var id: String { title }
    }

    /// 依据分数定位 + 意向城市 + 意向学科 + 就业景气 + 冲稳保分布生成建议
    static func buildAdvice(profile: StudentProfile, list: [Evaluated], engine: AdmissionEngine) -> [Advice] {
        let store = DataStore.shared
        let prov = store.province(profile.provId)
        let cur = engine.currentLines(prov, profile.track, override: override(of: profile))
        let rank = profile.rank ?? engine.rankOfScore(prov, store.currentYear, profile.track, profile.score)
        let diff = profile.score - cur.special
        let reachable = list.filter { $0.prob >= 0.18 }
        let chong = reachable.filter { $0.tier == "冲" }
        let wen = reachable.filter { $0.tier == "稳" }
        let bao = reachable.filter { $0.tier == "保" }
        var out: [Advice] = []

        out.append(
            Advice(
                title: "分数定位",
                text: "\(prov.name)\(profile.track.label) \(Int(profile.score)) 分，\(diff >= 0 ? "高于" : "低于")特殊类型线 \(Int(abs(diff.rounded()))) 分，省内约 \((rank / 10000).rounded(toPlaces: 1)) 万名，处于\(engine.batchOf(profile.score, cur))区间。匹配到 \(reachable.count) 所可考虑的院校（冲 \(chong.count) / 稳 \(wen.count) / 保 \(bao.count)）。",
                tone: .info
            )
        )

        if bao.isEmpty {
            out.append(
                Advice(
                    title: "保底不足，退档风险高",
                    text: "当前分数下匹配到的稳妥院校偏少，务必增加 5-8 个低于自身等效分 20 分以上的保底志愿，并勾选服从专业调剂，避免滑档。",
                    tone: .warn
                )
            )
        } else {
            out.append(
                Advice(
                    title: "梯度建议",
                    text: "建议按「冲 \(Swift.min(chong.count, 12)) 个 / 稳 \(Swift.min(Swift.max(wen.count, 8), 18)) 个 / 保 \(Swift.min(Swift.max(bao.count, 6), 12)) 个」排列，保底志愿的等效分建议比你低 \(Swift.max(12, Int(abs(diff).rounded() * 0.15)) + 12) 分以上。",
                    tone: .good
                )
            )
        }

        let volatile = chong.filter { $0.rec.volatility >= 6 }
            .sorted { $0.rec.volatility > $1.rec.volatility }.prefix(3)
        if !volatile.isEmpty {
            out.append(
                Advice(
                    title: "可以博“大小年”的冲刺校",
                    text: "\(volatile.map { "\($0.rec.seed.name)（三年线差波动 ±\($0.rec.volatility.rounded(toPlaces: 1)) 分）" }.joined(separator: "、"))，波动越大越可能在今年出现“小年”，适合放在志愿表前段冲刺。",
                    tone: .info
                )
            )
        }

        let empList = reachable.compactMap { EmploymentModel.forecast(name: $0.rec.seed.name, engine.dataset) }
        if !empList.isEmpty {
            let rising = empList.filter { $0.trend == "上升" }
            let pressed = empList.filter { $0.trend == "承压" }
            let topEmp = empList.sorted { $0.prosperity > $1.prosperity }.prefix(3)
            let medSalary5y = empList.sorted { $0.salary5y < $1.salary5y }[empList.count / 2].salary5y
            let share = Double(rising.count) / Double(empList.count)
            out.append(
                Advice(
                    title: "按就业景气挑院校",
                    text: "可考虑的 \(empList.count) 所院校中，就业景气最高的是 \(topEmp.map { "\($0.uniName)（景气 \(Int($0.prosperity))，5 年月薪约 \(Int($0.salary5y)) 元）" }.joined(separator: "、"))；组内 5 年月薪中位数约 \(Int(medSalary5y)) 元。其中 \(rising.count) 所主力学科处于招聘上升周期（\(Int(share * 100))%）\(pressed.isEmpty ? "" : "，\(pressed.count) 所处于承压周期")。\(share >= 0.4 ? "赛道结构健康，可在冲稳保各段优先安排景气上升的院校。" : "建议用「院校推荐 → 排序：就业」或「只看就业景气上升」筛选，补充 3-5 个景气上升方向的志愿。")",
                    tone: share >= 0.4 ? .good : .warn
                )
            )
        }

        if !profile.cities.isEmpty {
            let picked = store.cityCareers.filter { profile.cities.contains($0.name) }
            if !picked.isEmpty {
                let best = picked.sorted { $0.prosperity > $1.prosperity }[0]
                let text = picked.map { "\($0.name)：主导产业 \($0.industries.prefix(2).joined(separator: "/"))，平均招聘月薪 \(Int($0.salary)) 元，生活成本指数 \(Int($0.cost))，落户\($0.settle)" }.joined(separator: "；")
                out.append(
                    Advice(
                        title: "意向城市就业判断",
                        text: "\(text)。其中 \(best.name) 就业景气指数最高（\(Int(best.prosperity))），\(best.policy)",
                        tone: .info
                    )
                )
            }
        }

        if !profile.majors.isEmpty {
            let picked = store.majorCareers.filter { profile.majors.contains($0.name) }
            if !picked.isEmpty {
                out.append(
                    Advice(
                        title: "学科就业趋势",
                        text: picked.map { "\($0.name)：就业率 \($0.employRate)%、应届起薪 \(Int($0.salaryMin))-\(Int($0.salaryMax)) 元、趋势\($0.trend)（\($0.trendNote)）" }.joined(separator: " "),
                        tone: picked.contains(where: { $0.trend == "承压" }) ? .warn : .good
                    )
                )
                let risky = picked.filter { $0.trend == "承压" }
                if !risky.isEmpty {
                    out.append(
                        Advice(
                            title: "专业结构风险提示",
                            text: "\(risky.map(\.name).joined(separator: "、")) 当前招聘景气度偏弱，建议同一志愿组内搭配景气度上升的方向（如计算机/电气/新能源），或选择“专业 + 数据能力”的复合路径。",
                            tone: .warn
                        )
                    )
                }
            }
        }

        let inProv = reachable.filter { $0.rec.inProvince }.prefix(3)
        if !inProv.isEmpty {
            out.append(
                Advice(
                    title: "省内院校的性价比",
                    text: "本省院校在本地投放的计划通常是外省同层次院校的 3 倍以上，录取线差平均低 10 分左右。可重点考虑：\(inProv.map(\.rec.seed.name).joined(separator: "、"))。若计划毕业后留在本省就业，本地院校的校友与实习资源优势更明显。",
                    tone: .good
                )
            )
        }

        out.append(
            Advice(
                title: "填报动作清单",
                text: "① 出分后核对省考试院一分一段表，校准位次与今年批次线（当前参考特殊类型线 \(Int(cur.special)) 分 / 本科线 \(Int(cur.undergrad)) 分）；② 按“冲稳保”从高到低排序，前段放冲刺、后段放保底；③ \(profile.obeyAdjust ? "已勾选服从调剂，退档风险较低" : "未勾选服从调剂，建议勾选以降低退档风险")；④ 查看目标院校招生章程中的单科成绩、体检与选科限制。",
                tone: .info
            )
        )
        return out
    }

    // MARK: - 智能生成志愿表（核心功能）

    /// 智能生成志愿表的偏好（向导收集，写入档案后复用）
    struct GenPrefs: Equatable {
        var cities: [String] = []          // 空 = 不限
        var disciplines: [String] = []     // 学科门类，空 = 不限
        var hotMajors: [String] = []       // 细分热门专业，空 = 不限
        var obeyAdjust: Bool = true
        var strategy: GenStrategy = .balanced
        var preferProvince: Bool = true
        /// 考生选考科目（含首选科目）；空 = 未填，不做选科过滤
        var subjects: [String] = []
        /// 选科过滤的定位信息：省份 + 科类 + 年份决定用哪一批专业录取线
        var provId: String = ""
        var track: Track = .phy
        var year: Int = 0

        static func from(_ p: StudentProfile) -> GenPrefs {
            GenPrefs(
                cities: p.cities,
                disciplines: p.majors,
                hotMajors: p.hotMajors,
                obeyAdjust: p.obeyAdjust,
                strategy: p.strategy,
                preferProvince: p.preferProvince,
                subjects: p.subjects,
                provId: p.provId,
                track: p.track,
                year: DataStore.shared.currentYear
            )
        }
    }

    struct GenResult {
        var items: [VolunteerItem] = []
        var chong = 0
        var wen = 0
        var bao = 0
        /// 参与匹配的院校数（录取概率 ≥15%）
        var pool = 0
        /// 命中偏好（城市或专业）的院校数
        var matched = 0
        var warnings: [String] = []
    }

    /// 学科门类 → 院校类型：类型命中即认为该校开设该门类
    static let disciplineKinds: [String: [String]] = [
        "工学": ["理工"],
        "理学": ["理工", "综合"],
        "医学": ["医药"],
        "经济学": ["财经", "综合"],
        "管理学": ["财经", "综合"],
        "文学": ["语言", "师范", "综合"],
        "法学": ["政法"],
        "教育学": ["师范"],
        "农学": ["农林"],
        "历史学": ["师范", "综合"],
        "哲学": ["综合"],
        "艺术学": ["艺术"],
    ]

    /// 学科门类 → 该门类下的代表专业名（用于匹配院校王牌专业 / 优势学科）
    static var disciplineMajors: [String: [String]] = {
        var map: [String: [String]] = [:]
        for p in DataStore.shared.majorProfiles { map[p.discipline, default: []].append(p.name) }
        return map
    }()

    /// 把「自动化 / 机器人工程」「师范类（汉语言/数学）」这类复合名拆成可匹配的子关键词
    static func keywordVariants(_ name: String) -> [String] {
        var inner = ""
        var cleaned = ""
        var openBracket: Character?
        for ch in name {
            if openBracket == nil, ch == "（" || ch == "(" { openBracket = ch; continue }
            if let b = openBracket {
                if (b == "（" && ch == "）") || (b == "(" && ch == ")") { openBracket = nil }
                else { inner.append(ch) }
                continue
            }
            cleaned.append(ch)
        }
        let seps = CharacterSet(charactersIn: "/、,，|")
        var parts = [name, cleaned, inner]
        parts += cleaned.components(separatedBy: seps)
        parts += inner.components(separatedBy: seps)
        var seen = Set<String>()
        return parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 && seen.insert($0).inserted }
    }

    /// 院校与「意向专业」的命中项，用于排序与生成理由（只做命中，不做数值推测）
    static func majorHits(_ seed: UniversitySeed, _ prefs: GenPrefs) -> [String] {
        var hits: [String] = []
        guard !prefs.disciplines.isEmpty || !prefs.hotMajors.isEmpty else { return hits }
        let texts = seed.majors + seed.strengths
        let hitByKeyword: ([String]) -> Bool = { keywords in
            texts.contains { t in
                keywords.contains { k in t.contains(k) || (k.count >= 3 && k.contains(t)) }
            }
        }
        for d in prefs.disciplines {
            if disciplineKinds[d]?.contains(seed.kind) == true { hits.append(d) }
            else if hitByKeyword(disciplineMajors[d] ?? []) { hits.append(d) }
        }
        for hm in prefs.hotMajors where hitByKeyword(keywordVariants(hm)) {
            hits.append(hm)
        }
        var seen = Set<String>()
        return hits.filter { seen.insert($0).inserted }
    }

    /// 各策略下冲 / 稳 / 保的目标个数
    static func planCounts(_ prefs: GenPrefs) -> (chong: Int, wen: Int, bao: Int) {
        let base: (Int, Int, Int)
        switch prefs.strategy {
        case .aggressive: base = (18, 14, 10)
        case .balanced: base = (12, 18, 12)
        case .conservative: base = (6, 16, 20)
        }
        // 不服从调剂 → 退档就掉到下一批次：压缩冲刺、加厚保底
        if prefs.obeyAdjust { return base }
        return (max(2, base.0 - 4), base.1, base.2 + 6)
    }

    /**
     * 智能生成志愿表（核心功能）。
     * 流程：按录取概率分层 → 每层按「意向城市 / 意向专业 / 是否优先本省 / 就业景气」排序取前 N 个
     * → 各层内部按等效分从高到低排列 → 输出「冲 → 稳 → 保」顺序的志愿条目。
     * 只挑录取概率 ≥15% 的院校：**一个都挑不出来时返回空**，由调用方提示用户，
     * 既不编造「虚假保底」，也不会在挑不出来时清空用户已有的志愿表。
     */
    static func genVolunteers(_ list: [Evaluated], prefs: GenPrefs, ds: OfficialDataset? = nil) -> GenResult {
        var res = GenResult()
        let candidates = list.filter { $0.prob >= 0.15 }
        guard !candidates.isEmpty else { return res }

        // 选科硬过滤：只对「有专业录取线数据」的院校生效；该校已录专业都不符合选科要求 → 剔除，避免推荐根本报不了的专业组
        let majorsByUni = Dictionary(
            grouping: (ds?.majorAdmissions ?? []).filter { $0.provId == prefs.provId && $0.track == prefs.track && $0.year == prefs.year },
            by: { normalizeUniName($0.uniName) }
        )
        let pool = candidates.filter { e in
            guard !prefs.subjects.isEmpty, let rows = majorsByUni[normalizeUniName(e.rec.seed.name)] else { return true }
            return rows.contains { $0.meets(prefs.subjects) }
        }
        let blocked = candidates.count - pool.count
        if blocked > 0 {
            res.warnings.append("按你的选考科目（\(prefs.subjects.joined(separator: "/"))）剔除了 \(blocked) 所已录专业均不符合选科要求的院校；未导入专业录取线的院校不参与该过滤。")
        }
        // 有专业数据但符合选科的专业很少 → 提示专业选择面窄
        if !prefs.subjects.isEmpty, !majorsByUni.isEmpty {
            let narrow = pool.filter { e in
                guard let rows = majorsByUni[normalizeUniName(e.rec.seed.name)] else { return false }
                return rows.filter { $0.meets(prefs.subjects) }.count <= 2
            }
            if !narrow.isEmpty {
                res.warnings.append("\(narrow.map(\.rec.seed.name).prefix(3).joined(separator: "、"))等 \(narrow.count) 所院校符合你选科的专业不足 3 个，专业选择面窄，务必确认有能接受的专业再填。")
            }
        }
        guard !pool.isEmpty else { return res }
        res.pool = pool.count

        let empMap = EmploymentModel.allForecasts(ds)
        var hits: [String: [String]] = [:]
        for e in pool {
            let h = majorHits(e.rec.seed, prefs)
            hits[e.rec.seed.name] = h
            res.matched += (h.isEmpty && !(prefs.cities.contains(e.rec.seed.city))) ? 0 : 1
        }

        let scoreOf: (Evaluated) -> Double = { e in
            let seed = e.rec.seed
            var sc = 0.0
            if prefs.cities.contains(seed.city) { sc += 30 }
            sc += 12 * Double(hits[seed.name]?.count ?? 0)
            if prefs.preferProvince && e.rec.inProvince { sc += 10 }
            sc += (empMap[seed.name]?.prosperity ?? 60) * 0.15
            sc += e.rec.heat * 0.06
            return sc
        }

        let want = planCounts(prefs)
        let totalWant = want.chong + want.wen + want.bao
        var groups: [String: [Evaluated]] = ["冲": [], "稳": [], "保": []]
        var taken: Set<String> = []

        func put(_ key: String, _ e: Evaluated) {
            guard !taken.contains(e.rec.seed.name) else { return }
            taken.insert(e.rec.seed.name)
            groups[key, default: []].append(e)
        }
        func best(_ from: [Evaluated], _ n: Int) -> [Evaluated] {
            let cand = from.filter { !taken.contains($0.rec.seed.name) }
                .sorted { a, b in
                    let sa = scoreOf(a), sb = scoreOf(b)
                    return sa != sb ? sa > sb : a.rec.equivScore > b.rec.equivScore
                }
            return n <= 0 ? [] : Array(cand.prefix(n))
        }
        func total() -> Int { groups.values.reduce(0) { $0 + $1.count } }
        func groupKey(_ tier: String) -> String { tier == "稳" ? "稳" : tier == "保" ? "保" : "冲" }

        // 1) 各层按配额挑最贴合偏好的院校
        best(pool.filter { $0.tier == "冲" }, want.chong).forEach { put("冲", $0) }
        best(pool.filter { $0.tier == "稳" }, want.wen).forEach { put("稳", $0) }
        best(pool.filter { $0.tier == "保" }, want.bao).forEach { put("保", $0) }

        // 2) 保底不足时，用极高概率院校补齐到至少 6 个，避免编造虚假保底
        if groups["保"]!.count < min(6, want.bao) {
            best(pool.filter { $0.tier == "保" || $0.prob > 0.85 }, min(6, want.bao) - groups["保"]!.count)
                .forEach { put("保", $0) }
        }

        // 3) 某一层挑不满时，剩余名额下沉给更安全的层（保 → 稳 → 冲）
        for key in ["保", "稳", "冲"] {
            let want2 = key == "保" ? want.bao : key == "稳" ? want.wen : want.chong
            guard groups[key]!.count < want2, total() < totalWant else { continue }
            best(pool.filter { $0.tier == key }, min(want2 - groups[key]!.count, totalWant - total()))
                .forEach { put(key, $0) }
        }

        // 4) 仍然没填满目标总数时（典型场景：高分考生所有院校都是「保」），按偏好命中度补齐
        if total() < totalWant {
            best(pool, totalWant - total()).forEach { put(groupKey($0.tier), $0) }
        }

        // 每组内部按等效分从高到低，保证平行志愿检索时梯度单调
        let desc: (Evaluated, Evaluated) -> Bool = { $0.rec.equivScore > $1.rec.equivScore }
        let ordered: [(String, Evaluated)] =
            groups["冲"]!.sorted(by: desc).map { ("冲", $0) }
            + groups["稳"]!.sorted(by: desc).map { ("稳", $0) }
            + groups["保"]!.sorted(by: desc).map { ("保", $0) }

        let reasonOf: (Evaluated) -> String? = { e in
            var tags: [String] = []
            if let h = hits[e.rec.seed.name], !h.isEmpty {
                tags.append("专业匹配：" + h.prefix(2).joined(separator: "、"))
            }
            if prefs.cities.contains(e.rec.seed.city) { tags.append("意向城市") }
            if e.rec.inProvince { tags.append("本省院校") }
            return tags.isEmpty ? nil : tags.joined(separator: " · ")
        }

        res.items = ordered.map { tier, e in
            VolunteerItem(uniName: e.rec.seed.name, tier: tier, prob: e.prob, note: reasonOf(e))
        }
        res.chong = groups["冲"]!.count
        res.wen = groups["稳"]!.count
        res.bao = groups["保"]!.count

        if res.bao == 0 {
            res.warnings.append("没有找到稳妥的保底院校，建议下调目标层次或到「院校推荐」手动挑选。")
        } else if res.bao < 6 {
            res.warnings.append("保底志愿只有 \(res.bao) 个（建议 6 个以上），可在「院校推荐」手动补充下一层次院校。")
        }
        if !prefs.obeyAdjust {
            res.warnings.append("未选择服从专业调剂：一旦分数够不到所填专业会被退档，已自动压缩冲刺、加厚保底，仍建议勾选服从调剂。")
        }
        if res.chong == 0 {
            res.warnings.append("该分数段暂无可冲刺的院校，志愿表以稳、保为主。")
        }
        if !prefs.cities.isEmpty && res.matched == 0 {
            res.warnings.append("所选意向城市在当前分数段没有可录院校，已按不限城市生成；如坚持城市优先，建议降低院校层次要求。")
        }
        return res
    }

    static func override(of profile: StudentProfile) -> CurrentLines? {
        guard let o = profile.linesOverride else { return nil }
        if o.special == nil && o.undergrad == nil && o.college == nil { return nil }
        let base = DataStore.shared.province(profile.provId).lines(year: 2024, track: profile.track)!
        return CurrentLines(
            special: o.special ?? base.special,
            undergrad: o.undergrad ?? base.undergrad,
            college: o.college ?? base.college
        )
    }
}
