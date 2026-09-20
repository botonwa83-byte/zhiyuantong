import Charts
import SwiftUI

struct UniDetailView: View {
    @EnvironmentObject var state: AppState
    var uniName: String

    private var evaluated: Evaluated? { state.evals.first { $0.rec.seed.name == uniName } }
    private var seed: UniversitySeed? { DataStore.shared.seeds.first { $0.name == uniName } }
    private var emp: EmploymentForecast? { EmploymentModel.forecast(name: uniName, state.dataset) }

    var body: some View {
        ScrollView {
            if let e = evaluated, let s = seed {
                VStack(alignment: .leading, spacing: 14) {
                    header(e: e, s: s)
                    probabilityCard(e: e)
                    majorCard
                    historyCard(e: e)
                    if let emp { EmploymentReportView(f: emp) }
                    addButton(e: e)
                }
                .padding(14)
            } else {
                EmptyHint(text: "未找到该院校的匹配数据")
            }
        }
        .background(Color.ink50.opacity(0.6))
        .navigationTitle(uniName)
        .inlineNavTitle()
    }

    private func header(e: Evaluated, s: UniversitySeed) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(s.name).font(.title3.weight(.semibold)).foregroundStyle(Color.ink900)
                TierTag(tier: e.tier)
                if e.rec.inProvince { Text("本省").font(.caption2).foregroundStyle(Color.ink500) }
            }
            Text("\(s.city) · \(s.level) · \(s.kind)")
                .font(.caption).foregroundStyle(Color.ink400)
            if !s.strengths.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(s.strengths, id: \.self) { t in
                            Text(t).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                        }
                    }
                }
            }
        }
        .card()
    }

    private func probabilityCard(e: Evaluated) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "录取概率测算", sub: "线差法 50% + 平均位次法 30% + 最低位次摸高 20%")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(e.prob * 100))%").font(.system(size: 30, weight: .semibold)).monospacedDigit().foregroundStyle(Color.brand)
                Text(e.tier).font(.subheadline).foregroundStyle(Color.ink500)
            }
            ProbBar(prob: e.prob)
            HStack(spacing: 8) {
                MiniStat(label: "今年等效分", value: "\(Int(e.rec.equivScore))", sub: "你的分数 \(Int(state.profile?.score ?? 0))")
                MiniStat(label: "平均位次", value: "\((e.rec.avgRank / 10000).rounded(toPlaces: 1)) 万", sub: "你的位次 \((state.rank / 10000).rounded(toPlaces: 1)) 万")
            }
            HStack(spacing: 8) {
                MiniStat(label: "三年线差", value: "\(e.rec.delta3 >= 0 ? "+" : "")\(e.rec.delta3.rounded(toPlaces: 1))", sub: "波动 ±\(e.rec.volatility.rounded(toPlaces: 1))")
                MiniStat(label: "院校热度", value: "\(Int(e.rec.heat))")
            }
        }
        .card()
    }

    /// 专业级录取线：需要导入「专业录取线」CSV 后才显示；带选科要求的会按考生选科标注是否符合
    private var majorCard: some View {
        let provId = state.profile?.provId ?? ""
        let track = state.profile?.track ?? .phy
        let subjects = state.profile?.subjects ?? []
        let year = DataStore.shared.currentYear
        let rows = findMajorAdmissions(state.dataset, uniName, provId, track, year)
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(
                        title: "专业录取线",
                        sub: "\(year) 年 · \(trackLabel(track, DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312)) · 共 \(rows.count) 个专业"
                    )
                    ForEach(Array(rows.prefix(10))) { m in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(m.majorName).font(.caption.weight(.semibold)).foregroundStyle(Color.ink900)
                                Text("最低 \(Int(m.score)) 分"
                                     + (m.rank.map { " · 位次 \(Int($0))" } ?? "")
                                     + (m.plan.map { " · 计划 \(Int($0)) 人" } ?? ""))
                                    .font(.caption2).foregroundStyle(Color.ink500)
                            }
                            Spacer()
                            if let req = m.subjectReq, !req.isEmpty {
                                Text(req).font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                            }
                            if !subjects.isEmpty && !m.meets(subjects) {
                                Text("选科不符").font(.system(size: 10)).padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.danger.opacity(0.12))).foregroundStyle(Color.danger)
                            }
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                    if rows.count > 10 { Text("仅显示分数最高的 10 个专业").font(.caption2).foregroundStyle(Color.ink400) }
                }
                .card()
            }
        }
    }

    private func historyCard(e: Evaluated) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                title: "近三年录取数据",
                sub: e.rec.officialYears > 0 ? "含 \(e.rec.officialYears) 年官方投档线" : "内置模型推算，导入官方数据后自动替换"
            )
            ForEach(e.rec.years) { y in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(y.year)").font(.caption.monospacedDigit()).frame(width: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("投档线 \(Int(y.score)) 分 · 位次约 \((y.rank / 10000).rounded(toPlaces: 1)) 万 · 线差 \(y.diff >= 0 ? "+" : "")\(y.diff.rounded(toPlaces: 1))")
                            .font(.caption).foregroundStyle(Color.ink700)
                        Text("计划 \(Int(y.plan)) 人 · 报考热度 \(Int(y.applicants)) · 录取率 \(Int(y.admitRate * 100))%" + (y.official == true ? " · 官方数据" : ""))
                            .font(.caption2).foregroundStyle(y.official == true ? Color.good : Color.ink400)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                Divider()
            }
            BarChartView(
                labels: e.rec.years.map { String($0.year) },
                values: e.rec.years.map(\.diff),
                height: 140
            )
            Text("上图：三年线差（分）").font(.caption2).foregroundStyle(Color.ink400)
        }
        .card()
    }

    private func addButton(e: Evaluated) -> some View {
        let picked = state.volunteers.contains { $0.uniName == uniName }
        return Button {
            state.addVolunteer(uniName)
        } label: {
            Text(picked ? "已在志愿表" : "加入志愿表")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(picked ? Color.good.opacity(0.15) : Color.brand))
                .foregroundStyle(picked ? Color.good : Color.white)
        }
        .disabled(picked)
    }
}
