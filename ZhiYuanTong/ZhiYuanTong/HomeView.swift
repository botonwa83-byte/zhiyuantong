import Charts
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var showGen = false

    private var profile: StudentProfile { state.profile ?? .placeholder }
    private var prov: Province { state.prov }
    private var cur: CurrentLines { state.cur }

    private var diff: Double { profile.score - cur.special }
    private var reachable: [Evaluated] { state.evals.filter { $0.prob >= 0.18 } }

    private func count(_ tier: String) -> Int { reachable.filter { $0.tier == tier }.count }

    private var hasRankTable: Bool {
        state.engine.dataset.rankTables.contains { $0.provId == prov.id && $0.year == DataStore.shared.currentYear && $0.track == profile.track }
    }

    private var officialUnis: Int { state.evals.filter { $0.rec.officialYears > 0 }.count }

    private var topPicks: [Evaluated] {
        reachable.sorted {
            ($0.prob * 0.6 + $0.rec.heat / 100 * 0.4) > ($1.prob * 0.6 + $1.rec.heat / 100 * 0.4)
        }.prefix(5).map { $0 }
    }

    private var advice: [Recommend.Advice] {
        Recommend.buildAdvice(profile: profile, list: state.evals, engine: state.engine)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    dataSourceNote
                    statRow
                    genCard
                    trendCard
                    HStack(alignment: .top, spacing: 12) {
                        rateCard
                        tierCard
                    }
                    adviceCard
                    topPicksCard
                    footerNote
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("概览")
            .sheet(isPresented: $showGen) {
                GenWizardView(prefs: Recommend.GenPrefs.from(profile))
                    .environmentObject(state)
            }
        }
    }

    // MARK: - 片段

    /// 智能生成志愿表入口（软件核心功能）
    private var genCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "智能生成志愿表", sub: "四步：选意向城市 → 选意向专业 → 定是否服从调剂与梯度 → 生成")
            Text("当前分数下可考虑 \(reachable.count) 所院校（冲 \(count("冲")) / 稳 \(count("稳")) / 保 \(count("保"))），生成结果自动写入志愿表并跳转过去。")
                .font(.caption).foregroundStyle(Color.ink700)
                .fixedSize(horizontal: false, vertical: true)
            Button { showGen = true } label: {
                Text("开始生成")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brand))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            if !state.volunteers.isEmpty {
                Text("当前志愿表已有 \(state.volunteers.count) 个志愿，重新生成会覆盖。")
                    .font(.caption2).foregroundStyle(Color.ink400)
            }
        }
        .card()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.brandSoft))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(prov.name) · \(trackLabel(profile.track, prov.mode)) · \(state.engine.batchOf(profile.score, cur))")
                .font(.caption)
                .foregroundStyle(Color.ink400)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(profile.score))")
                    .font(.system(size: 40, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink900)
                Text("分").font(.caption).foregroundStyle(Color.ink400)
                Text("\(diff >= 0 ? "超特殊类型线 +" : "低于特殊类型线 ")\(Int(abs(diff.rounded())))")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(diff >= 0 ? Color.good : Color.danger)
            }
        }
    }

    private var dataSourceNote: some View {
        let text: String = {
            if officialUnis > 0 || hasRankTable {
                var parts: [String] = []
                if hasRankTable { parts.append("\(DataStore.shared.currentYear) 年一分一段表") }
                if officialUnis > 0 { parts.append("\(officialUnis) 所院校真实投档线") }
                return "已接入官方数据：" + parts.joined(separator: " · ")
            }
            return "数据模式：内置示例模型。可在「我的 → 官方数据接入」导入一分一段表与投档线，切换为真实数据"
        }()
        return Text(text).font(.caption2).foregroundStyle(Color.ink400)
    }

    private var statRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(
                    label: "省内位次（估算）",
                    value: "\((state.rank / 10000).rounded(toPlaces: 1)) 万",
                    sub: hasRankTable ? "来自官方一分一段表" : "按经验曲线估算",
                    tone: .brand
                )
                StatTile(
                    label: "今年参考批次线",
                    value: "\(Int(cur.special))",
                    sub: "本科线 \(Int(cur.undergrad)) / 专科线 \(Int(cur.college))"
                )
            }
            HStack(spacing: 10) {
                StatTile(label: "可考虑院校", value: "\(reachable.count)", sub: "共 \(state.evals.count) 所参与匹配")
                StatTile(
                    label: "冲 / 稳 / 保",
                    value: "\(count("冲")) / \(count("稳")) / \(count("保"))",
                    sub: count("保") >= 6 ? "保底充足" : "保底偏少，需补充",
                    tone: count("保") >= 6 ? .good : .warn
                )
            }
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "本省近三年分数线趋势", sub: "特殊类型线 ≈ 原一本/强基线，是跨年份对比的锚点")
                Spacer()
                Text(state.trend.map { String($0.year) }.joined(separator: " → "))
                    .font(.caption2).foregroundStyle(Color.ink400)
            }
            LineChartView(
                labels: state.trend.map { String($0.year) },
                series: [
                    LineSeries(name: "特殊类型线", values: state.trend.map(\.special), color: Color.brand),
                    LineSeries(name: "本科线", values: state.trend.map(\.undergrad), color: Color.good),
                ]
            )
        }
        .card()
    }

    private var rateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "上线率与录取率", sub: "上线率 = 本科线上人数占比")
            LineChartView(
                labels: state.trend.map { String($0.year) },
                series: [
                    LineSeries(name: "本科上线率", values: state.trend.map(\.onlineRate), color: Color.warn),
                    LineSeries(name: "本科录取率", values: state.trend.map(\.admitRate), color: Color.brand, dashed: true),
                ],
                height: 150
            )
        }
        .card()
        .frame(maxWidth: .infinity)
    }

    private var tierCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "冲稳保分布", sub: "按录取概率分层统计")
            BarChartView(
                labels: ["冲", "稳", "保"],
                values: [Double(count("冲")), Double(count("稳")), Double(count("保"))],
                colors: [Color.warn, Color.brand, Color.good],
                height: 150
            )
            Text(count("保") >= 6 ? "保底院校充足，可适度增加冲刺数量" : "建议再补充省内院校或下一层次院校作为保底")
                .font(.caption2).foregroundStyle(Color.ink400)
            Button {
                showGen = true
            } label: {
                Text("智能生成志愿表")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.brandSoft))
                    .foregroundStyle(Color.brand)
            }
        }
        .card()
        .frame(maxWidth: .infinity)
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "填报建议", sub: "结合分数定位、城市与学科就业趋势自动生成")
            ForEach(advice) { a in
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink900)
                    Text(a.text).font(.caption).foregroundStyle(Color.ink700)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(bg(of: a.tone)))
            }
        }
        .card()
    }

    private func bg(of tone: Recommend.Advice.Tone) -> Color {
        switch tone {
        case .warn: return Color.warn.opacity(0.1)
        case .good: return Color.good.opacity(0.1)
        case .info: return Color.ink50
        }
    }

    private var topPicksCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "优先关注", sub: "综合录取概率、院校热度与就业质量排序")
            ForEach(topPicks) { e in
                NavigationLink(value: e.rec.seed.name) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(e.rec.seed.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink900)
                                TierTag(tier: e.tier)
                            }
                            Text("\(e.rec.seed.city) · \(e.rec.seed.level) · 等效分 \(Int(e.rec.equivScore)) · 位次约 \((e.rec.avgRank / 10000).rounded(toPlaces: 1)) 万")
                                .font(.caption2).foregroundStyle(Color.ink400)
                            ProbBar(prob: e.prob)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.ink200)
                    }
                    .padding(.vertical, 8)
                }
                Divider()
            }
        }
        .card()
        .navigationDestination(for: String.self) { name in
            UniDetailView(uniName: name)
        }
    }

    private var footerNote: some View {
        Text("数据来源说明：省份批次线与院校录取数据为公开信息整理后的模型化示例，正式填报请以各省教育考试院公布的《一分一段表》《招生计划》与院校招生章程为准。")
            .font(.caption2)
            .foregroundStyle(Color.ink400)
    }
}
