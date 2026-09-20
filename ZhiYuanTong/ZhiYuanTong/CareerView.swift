import Charts
import SwiftUI

struct CareerView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .discipline

    enum Tab: String, CaseIterable, Identifiable {
        case discipline, major, uni, city
        var id: String { rawValue }
        var label: String {
            switch self {
            case .discipline: return "学科"
            case .major: return "专业"
            case .uni: return "院校就业"
            case .city: return "城市"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("就业洞察").font(.title2.weight(.semibold))
                        Text("填报前先看清学科、专业与院校的就业数据，避免「高分低就」与结构性失业")
                            .font(.caption).foregroundStyle(Color.ink400)
                        Picker("维度", selection: $tab) {
                            ForEach(Tab.allCases) { t in Text(t.label).tag(t) }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch tab {
                    case .discipline: DisciplineTab()
                    case .major: MajorTab()
                    case .uni: UniEmploymentTab()
                    case .city: CityTab()
                    }
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("就业洞察")
        }
    }
}

private func trendColor(_ t: String) -> Color {
    t == "上升" ? Color.good : t == "承压" ? Color.danger : Color.ink500
}

private struct TrendTag: View {
    var t: String
    var body: some View {
        Text(t).font(.caption2)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(trendColor(t).opacity(0.12)))
            .foregroundStyle(trendColor(t))
    }
}

// MARK: - 学科门类

private struct DisciplineTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let majors = state.profile?.majors, !majors.isEmpty {
                Text("你已选择的意向门类：\(majors.joined(separator: "、"))（可在「我的 → 档案」中修改）")
                    .font(.caption).foregroundStyle(Color.brand)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandSoft))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "学科门类就业率与深造率", sub: "百分制对比")
                BarChartView(
                    labels: DataStore.shared.majorCareers.map(\.name),
                    values: DataStore.shared.majorCareers.map(\.employRate),
                    colors: DataStore.shared.majorCareers.map { trendColor($0.trend) },
                    height: 190
                )
                HStack(spacing: 14) {
                    legend("景气上升", Color.good)
                    legend("平稳", Color.brand)
                    legend("承压", Color.danger)
                }
                .frame(maxWidth: .infinity)
            }
            .card()

            ForEach(DataStore.shared.majorCareers) { m in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(m.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink900)
                        Spacer()
                        TrendTag(t: m.trend)
                    }
                    HStack(spacing: 8) {
                        MiniStat(label: "就业率", value: "\(Int(m.employRate))%")
                        MiniStat(label: "深造率", value: "\(Int(m.furtherRate))%")
                        MiniStat(label: "5 年月薪", value: "\(Int(m.midSalary / 1000))k")
                    }
                    Text("应届起薪 \(Int(m.salaryMin)) - \(Int(m.salaryMax)) 元/月").font(.caption2).foregroundStyle(Color.ink400)
                    Text("就业方向：\(m.directions.joined(separator: "、"))").font(.caption2).foregroundStyle(Color.ink400)
                    Text("主要行业：\(m.industries.joined(separator: "、"))").font(.caption2).foregroundStyle(Color.ink400)
                    Text(m.trendNote).font(.caption).foregroundStyle(Color.ink700)
                    Text("建议：\(m.advice)").font(.caption).foregroundStyle(Color.brand)
                }
                .card()
            }
        }
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(Color.ink400)
        }
    }
}

// MARK: - 专业

private struct MajorTab: View {
    @State private var kw = ""
    @State private var discipline = ""

    private var disciplines: [String] {
        Array(Set(DataStore.shared.majorProfiles.map(\.discipline))).sorted()
    }

    private var list: [MajorProfile] {
        DataStore.shared.majorProfiles.filter { m in
            (discipline.isEmpty || m.discipline == discipline)
                && (kw.isEmpty || m.name.contains(kw) || m.jobs.contains(where: { $0.contains(kw) }) || m.industries.contains(where: { $0.contains(kw) }))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.ink400)
                TextField("搜索专业 / 岗位 / 行业（共 \(DataStore.shared.majorProfiles.count) 个专业）", text: $kw)
                    .font(.subheadline)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ink200, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "全部", active: discipline.isEmpty) { discipline = "" }
                    ForEach(disciplines, id: \.self) { d in
                        Chip(title: d, active: discipline == d) { discipline = d }
                    }
                }
            }

            Text("共 \(list.count) 个专业 · 数值为该专业全国中位数水平")
                .font(.caption2).foregroundStyle(Color.ink400)

            ForEach(list) { m in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(m.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink900)
                        Text(m.discipline).font(.system(size: 10)).foregroundStyle(Color.ink500)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.ink50))
                        Spacer()
                        TrendTag(t: m.trend)
                    }
                    HStack(spacing: 8) {
                        MiniStat(label: "就业率", value: "\(Int(m.employRate))%")
                        MiniStat(label: "深造率", value: "\(Int(m.furtherRate))%")
                    }
                    HStack(spacing: 8) {
                        MiniStat(label: "应届起薪", value: "\(String(format: "%.1f", m.salaryMin / 1000))-\(String(format: "%.1f", m.salaryMax / 1000))k")
                        MiniStat(label: "5 年月薪", value: "\(Int(m.mid5y / 1000))k")
                    }
                    Text("岗位方向：\(m.jobs.joined(separator: "、"))").font(.caption2).foregroundStyle(Color.ink400)
                    Text("主要行业：\(m.industries.joined(separator: "、"))").font(.caption2).foregroundStyle(Color.ink400)
                    Text("需求城市：\(m.cities.joined(separator: "、"))").font(.caption2).foregroundStyle(Color.ink400)
                    Text("选科要求：\(m.subjects)").font(.caption2).foregroundStyle(Color.ink400)
                    Text("门槛：\(m.barrier)").font(.caption2).foregroundStyle(Color.ink500)
                    if let hot = DataStore.shared.hotMajors.first(where: { $0.name == m.name }) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(hot.schools, id: \.self) { s in
                                    Text(s).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                                }
                            }
                        }
                        Text(hot.trendNote).font(.caption).foregroundStyle(Color.ink700)
                    }
                    if let risk = m.risk {
                        Text("风险：\(risk)").font(.caption2).foregroundStyle(Color.danger)
                    }
                }
                .card()
            }
        }
    }
}

// MARK: - 院校就业

private struct UniEmploymentTab: View {
    @EnvironmentObject var state: AppState
    @State private var kw = ""
    @State private var picked: String = ""

    private var candidates: [String] {
        let volunteerNames = state.volunteers.map(\.uniName)
        let reachable = state.evals.filter { $0.prob >= 0.15 }
            .sorted { $0.prob > $1.prob }.prefix(10).map(\.rec.seed.name)
        return Array(NSOrderedSet(array: volunteerNames + reachable).compactMap { $0 as? String })
    }

    private var list: [String] {
        if kw.trimmingCharacters(in: .whitespaces).isEmpty { return candidates }
        let q = kw.trimmingCharacters(in: .whitespaces)
        return DataStore.shared.seeds.filter { $0.name.contains(q) || $0.city.contains(q) }.prefix(24).map(\.name)
    }

    private var name: String {
        list.contains(picked) ? picked : (list.first ?? picked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.ink400)
                TextField("搜索院校（默认展示志愿表与高匹配院校，共 \(DataStore.shared.seeds.count) 所）", text: $kw)
                    .font(.subheadline)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ink200, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Text(kw.isEmpty ? "志愿表与高匹配院校" : "搜索结果 \(list.count) 所")
                    .font(.caption2).foregroundStyle(Color.ink400)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(list, id: \.self) { n in
                            Chip(title: n, active: n == name) { picked = n }
                        }
                    }
                }
            }
            .card()

            if let seed = DataStore.shared.seeds.first(where: { $0.name == name }),
               let f = EmploymentModel.forecast(name: name, state.dataset) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(seed.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.ink900)
                        TrendTag(t: f.trend)
                        if f.official {
                            Text("官方就业数据").font(.system(size: 10)).foregroundStyle(Color.good)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.good.opacity(0.12)))
                        }
                    }
                    let evaluated = state.evals.first { $0.rec.seed.name == name }
                    Text("\(seed.city) · \(seed.level) · \(seed.kind)" + (evaluated.map { " · 你的录取概率 \(Int($0.prob * 100))%（\($0.tier)）" } ?? ""))
                        .font(.caption).foregroundStyle(Color.ink400)
                }
                .card()

                EmploymentReportView(f: f)
            }
        }
        .onAppear { if picked.isEmpty { picked = candidates.first ?? DataStore.shared.seeds[0].name } }
    }
}

/// 院校就业质量报告（预测 / 官方数据）
struct EmploymentReportView: View {
    var f: EmploymentForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MiniStat(label: "落实率", value: "\(f.employRate)%", sub: "深造 \(f.furtherRate)%")
                MiniStat(label: "应届月薪", value: "\(Int(f.salaryMid))", sub: "区间 \(Int(f.salaryLo))-\(Int(f.salaryHi))")
            }
            HStack(spacing: 8) {
                MiniStat(label: "5 年月薪", value: "\(Int(f.salary5y))")
                MiniStat(label: "就业景气", value: "\(Int(f.prosperity))", sub: "同层次分位 \(Int(f.peerPercentile))%")
            }
            HStack(spacing: 8) {
                MiniStat(label: "专业对口率", value: "\(Int(f.relatedRate))%")
                MiniStat(label: "深造构成", value: "国内 \(Int(f.domesticRate))%", sub: "出国 \(Int(f.overseasRate))%")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("行业去向").font(.caption2).foregroundStyle(Color.ink400)
                ForEach(f.industries) { i in ShareRow(name: i.name, pct: i.pct, color: Color.brand) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("单位性质").font(.caption2).foregroundStyle(Color.ink400)
                ForEach(f.employers) { e in ShareRow(name: e.name, pct: e.pct, color: Color.good) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("就业城市").font(.caption2).foregroundStyle(Color.ink400)
                ForEach(f.cities) { c in ShareRow(name: c.name, pct: c.pct, color: Color.warn) }
            }

            if !f.majorProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("王牌专业画像").font(.caption2).foregroundStyle(Color.ink400)
                    ForEach(f.majorProfiles, id: \.name) { m in
                        HStack(spacing: 6) {
                            Text(m.name).font(.caption).foregroundStyle(Color.ink700)
                            Spacer()
                            TrendTag(t: m.trend)
                        }
                    }
                }
            }

            if !f.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("亮点").font(.caption2).foregroundStyle(Color.good)
                    ForEach(f.highlights, id: \.self) { t in Text("· \(t)").font(.caption).foregroundStyle(Color.ink700) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("风险提示").font(.caption2).foregroundStyle(Color.warn)
                ForEach(f.risks, id: \.self) { t in Text("· \(t)").font(.caption).foregroundStyle(Color.ink700) }
            }
        }
        .card()
    }
}

// MARK: - 城市

private struct CityTab: View {
    @State private var picked: [String] = []

    private var list: [CityCareer] {
        DataStore.shared.cityCareers.sorted { $0.prosperity > $1.prosperity }
    }

    private var filtered: [CityCareer] {
        picked.isEmpty ? list : list.filter { picked.contains($0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "城市就业景气与薪资", sub: "景气指数综合招聘需求、产业增速与人才流入")
                BarChartView(labels: list.prefix(12).map(\.name), values: list.prefix(12).map(\.prosperity), height: 170)
                BarChartView(labels: list.prefix(12).map(\.name), values: list.prefix(12).map(\.salary), singleColor: Color.good, height: 170)
                Text("下图：平均招聘月薪（元）").font(.caption2).foregroundStyle(Color.ink400).frame(maxWidth: .infinity)
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "筛选意向城市", sub: "可对比产业、薪资、生活成本与落户政策")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DataStore.shared.cityCareers) { c in
                            Chip(title: c.name, active: picked.contains(c.name)) {
                                picked = picked.contains(c.name) ? picked.filter { $0 != c.name } : picked + [c.name]
                            }
                        }
                        if !picked.isEmpty {
                            Button("清除") { picked = [] }.font(.caption).foregroundStyle(Color.ink400)
                        }
                    }
                }
            }
            .card()

            ForEach(filtered) { c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink900)
                        Spacer()
                        Text("景气 \(Int(c.prosperity))").font(.caption2).foregroundStyle(Color.brand)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.brandSoft))
                    }
                    HStack(spacing: 8) {
                        MiniStat(label: "平均月薪", value: "\(String(format: "%.1f", c.salary / 1000))k")
                        MiniStat(label: "生活成本", value: "\(Int(c.cost))")
                        MiniStat(label: "落户", value: c.settle)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(c.industries, id: \.self) { t in
                                Text(t).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.ink50)).foregroundStyle(Color.ink700)
                            }
                        }
                    }
                    Text(c.note).font(.caption).foregroundStyle(Color.ink700)
                    Text("人才政策：\(c.policy)").font(.caption2).foregroundStyle(Color.ink500)
                }
                .card()
            }
        }
    }
}
