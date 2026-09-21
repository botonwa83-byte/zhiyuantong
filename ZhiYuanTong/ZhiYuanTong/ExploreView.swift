import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var state: AppState

    @State private var filters = Filters.default
    @State private var showFilter = false
    @State private var limit = 60

    private static let levels = ["顶尖985", "985", "211", "双一流", "省重点", "普通本科", "民办/独立学院"]
    private static let kinds = ["综合", "理工", "师范", "财经", "政法", "医药", "农林", "语言", "艺术", "军工"]
    private static let hotCities = ["北京", "上海", "深圳", "广州", "杭州", "南京", "成都", "武汉", "西安", "苏州", "合肥", "长沙", "厦门", "天津", "重庆", "郑州", "青岛", "济南"]

    private var list: [Evaluated] {
        Recommend.filterAndSort(state.evals, filters, state.dataset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                    header
                    searchBar
                    if showFilter { filterPanel }
                    sortRow
                    if list.isEmpty {
                        EmptyHint(text: "没有符合条件的院校，试试放宽筛选条件")
                    } else {
                        ForEach(Array(list.prefix(limit).enumerated()), id: \.element.rec.seed.name) { _, e in
                            NavigationLink(value: e.rec.seed.name) {
                                UniRow(e: e, picked: state.volunteers.contains { $0.uniName == e.rec.seed.name && $0.batch == state.currentBatch }) {
                                    state.addVolunteer(e.rec.seed.name)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        if list.count > limit {
                            Button {
                                limit += 60
                            } label: {
                                Text("加载更多（还有 \(list.count - limit) 所）")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))
                                    .foregroundStyle(Color.ink700)
                            }
                        }
                        Text("已显示 \(min(limit, list.count)) / \(list.count) 所，共 \(state.evals.count) 所院校参与匹配")
                            .font(.caption2).foregroundStyle(Color.ink400)
                    }
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("院校推荐")
            .navigationDestination(for: String.self) { name in
                UniDetailView(uniName: name)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("基于 \(state.prov.name) · \(state.profile?.track.label ?? "") · \(Int(state.profile?.score ?? 0)) 分（位次约 \((state.rank / 10000).rounded(toPlaces: 1)) 万）匹配，共 \(state.evals.count) 所院校")
                .font(.caption)
                .foregroundStyle(Color.ink400)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.ink400)
                TextField("搜索院校 / 城市 / 专业", text: $filters.keyword)
                    .font(.subheadline)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ink200, lineWidth: 1))

            Button {
                showFilter.toggle()
            } label: {
                Text(filters.activeCount > 0 ? "筛选 \(filters.activeCount)" : "筛选")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(filters.activeCount > 0 ? Color.brand : Color.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(filters.activeCount > 0 ? Color.brand : Color.ink200, lineWidth: 1))
                    .foregroundStyle(filters.activeCount > 0 ? Color.white : Color.ink700)
            }
        }
        .onChange(of: filters) { _ in limit = 60 }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            chipGroup(title: "院校层次", items: Self.levels, selected: filters.levels) { v in
                filters.levels = toggled(filters.levels, v)
            }
            chipGroup(title: "院校类型", items: Self.kinds, selected: filters.kinds) { v in
                filters.kinds = toggled(filters.kinds, v)
            }
            chipGroup(title: "城市", items: Self.hotCities, selected: filters.cities) { v in
                filters.cities = toggled(filters.cities, v)
            }
            HStack {
                Chip(title: "只看本省院校", active: filters.onlyInProvince) { filters.onlyInProvince.toggle() }
                Chip(title: "只看稳妥（≥45%）", active: filters.safeOnly) { filters.safeOnly.toggle() }
                Chip(title: "只看就业景气上升", active: filters.risingOnly) { filters.risingOnly.toggle() }
                Chip(title: "显示全部院校", active: !filters.hideHopeless) { filters.hideHopeless.toggle() }
                Button("重置") { filters = .default; filters.hideHopeless = true }
                    .font(.caption).foregroundStyle(Color.ink400)
            }
        }
        .card()
    }

    private func chipGroup(title: String, items: [String], selected: [String], toggle: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Color.ink500)
            WrapStack(items: items) { item in
                Chip(title: item, active: selected.contains(item)) { toggle(item) }
            }
        }
    }

    private var sortRow: some View {
        HStack {
            SectionTitle(title: "匹配结果 \(list.count) 所")
            Spacer()
            Picker("排序", selection: $filters.sort) {
                ForEach(Filters.Sort.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 120)
        }
    }
}

private func toggled(_ arr: [String], _ v: String) -> [String] {
    arr.contains(v) ? arr.filter { $0 != v } : arr + [v]
}

/// 简易流式布局（SwiftUI 原生无 Wrap，按字符宽度折行）
struct WrapStack<Content: View>: View {
    var items: [String]
    var content: (String) -> Content

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0
                                height -= d.height + 8
                            }
                            let result = width
                            if item == items.last { width = 0 }
                            else { width -= d.width + 8 }
                            return result
                        }
                        .alignmentGuide(.top) { _ in height }
                }
            }
        }
        .frame(height: 120)
    }
}

// MARK: - 院校卡片

struct UniRow: View {
    var e: Evaluated
    var picked: Bool
    var onAdd: () -> Void

    private var emp: EmploymentForecast? { EmploymentModel.forecast(name: e.rec.seed.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(e.rec.seed.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink900)
                        TierTag(tier: e.tier)
                        if e.rec.inProvince { smallTag("本省", Color.ink500) }
                        if e.rec.officialYears > 0 {
                            smallTag("官方数据 \(e.rec.officialYears)/3 年", Color.good)
                        }
                    }
                    Text("\(e.rec.seed.city) · \(e.rec.seed.level) · \(e.rec.seed.kind)")
                        .font(.caption2).foregroundStyle(Color.ink400)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(e.rec.equivScore))")
                        .font(.system(size: 18, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.brand)
                    Text("今年等效分").font(.system(size: 10)).foregroundStyle(Color.ink400)
                }
            }

            HStack(spacing: 8) {
                MiniStat(label: "三年平均分", value: "\(Int(e.rec.avgScore))")
                MiniStat(label: "平均位次", value: "\((e.rec.avgRank / 10000).rounded(toPlaces: 1)) 万")
                MiniStat(
                    label: "应届月薪 / 景气",
                    value: "\(Int(emp?.salaryMid ?? e.rec.seed.salary))",
                    sub: emp?.trend ?? "—"
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("录取概率").font(.caption2).foregroundStyle(Color.ink400)
                    Spacer()
                    Text("三年线差 \(e.rec.delta3 >= 0 ? "+" : "")\(e.rec.delta3.rounded(toPlaces: 1)) 分 · 波动 ±\(e.rec.volatility.rounded(toPlaces: 1))")
                        .font(.caption2).foregroundStyle(Color.ink400)
                }
                ProbBar(prob: e.prob)
            }

            HStack {
                ForEach(e.rec.seed.strengths.prefix(2), id: \.self) { t in
                    Text(t).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                }
                if let emp {
                    Text("就业\(emp.trend) · 5 年 \(Int(emp.salary5y / 1000))k · 深造 \(Int(emp.furtherRate))%")
                        .font(.system(size: 10))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(emp.trend == "承压" ? Color.danger.opacity(0.1) : Color.good.opacity(0.1)))
                        .foregroundStyle(emp.trend == "承压" ? Color.danger : Color.good)
                }
                Spacer()
            }

            HStack {
                Spacer()
                Button(action: onAdd) {
                    Text(picked ? "已在志愿表" : "+ 加入志愿表")
                        .font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(picked ? Color.good.opacity(0.12) : Color.brandSoft))
                        .foregroundStyle(picked ? Color.good : Color.brand)
                }
                .buttonStyle(.plain)
                .disabled(picked)
            }
        }
        .card()
    }

    private func smallTag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 10))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}
