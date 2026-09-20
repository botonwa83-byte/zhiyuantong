import Charts
import SwiftUI

struct MyListView: View {
    @EnvironmentObject var state: AppState
    @State private var showGen = false

    private var items: [VolunteerItem] { state.volunteers }
    private var evalByName: [String: Evaluated] {
        Dictionary(uniqueKeysWithValues: state.evals.map { ($0.rec.seed.name, $0) })
    }

    private var forecasts: [EmploymentForecast] {
        items.compactMap { EmploymentModel.forecast(name: $0.uniName, state.dataset) }
    }

    private var emp: EmploymentModel.EmploymentAggregate? {
        EmploymentModel.aggregate(forecasts)
    }

    private var chong: Int { items.filter { $0.tier == "冲" }.count }
    private var wen: Int { items.filter { $0.tier == "稳" }.count }
    private var bao: Int { items.filter { $0.tier == "保" }.count }

    private var score: Double { state.profile?.score ?? 0 }

    /// 梯度倒挂：后面的学校比前面的更难考
    private var inversions: [Int] {
        let rows = items.enumerated().map { (i, v) -> (Int, Double) in
            (i, evalByName[v.uniName]?.rec.equivScore ?? 0)
        }
        var out: [Int] = []
        for (i, item) in rows.enumerated() where i > 0 {
            if item.1 > rows[i - 1].1 + 3 { out.append(i + 1) }
        }
        return out
    }

    private var riskyTop: Int {
        items.prefix(3).filter { (evalByName[$0.uniName]?.prob ?? 0) < 0.15 }.count
    }

    private var safetyGap: Double {
        guard let last = items.last, let e = evalByName[last.uniName] else { return 0 }
        return score - e.rec.equivScore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    statRow

                    if inversions.isEmpty == false || state.profile?.obeyAdjust == false || bao == 0 || riskyTop > 0 {
                        checkCard
                    }

                    if let emp { employmentCard(emp) }

                    if items.isEmpty {
                        EmptyHint(text: "还没有志愿，点击右上角「一键智能填充」快速生成冲稳保方案").card()
                    } else {
                        listCard
                    }

                    Text("志愿表保存在本机（iPhone / iPad / Mac 各自独立存储），可随时继续编辑；正式填报请在省考试院志愿填报系统中按此顺序录入。")
                        .font(.caption2).foregroundStyle(Color.ink400)
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("我的志愿表")
            .navigationDestination(for: String.self) { name in
                UniDetailView(uniName: name)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("一键智能填充") { showGen = true }
                        if !items.isEmpty {
                            Button("清空", role: .destructive) { state.clearVolunteers() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showGen) {
                GenWizardView(prefs: Recommend.GenPrefs.from(state.profile ?? .placeholder))
                    .environmentObject(state)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("我的志愿表").font(.title2.weight(.semibold))
            Text("平行志愿按「冲 → 稳 → 保」从上到下排列，共 \(items.count) 个")
                .font(.caption).foregroundStyle(Color.ink400)
        }
    }

    private var statRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(label: "志愿总数", value: "\(items.count)", sub: "建议 30-45 个")
                StatTile(label: "冲 / 稳 / 保", value: "\(chong) / \(wen) / \(bao)", sub: "建议 12 / 18 / 12")
            }
            HStack(spacing: 10) {
                StatTile(
                    label: "末尾安全垫",
                    value: "\(safetyGap >= 0 ? "+" : "")\(Int(safetyGap.rounded())) 分",
                    sub: items.isEmpty ? "尚无志愿" : "最后一个志愿的等效分差",
                    tone: safetyGap >= 12 ? .good : .warn
                )
                StatTile(
                    label: "服从调剂",
                    value: state.profile?.obeyAdjust == true ? "已勾选" : "未勾选",
                    sub: state.profile?.obeyAdjust == true ? "退档风险低" : "退档风险上升",
                    tone: state.profile?.obeyAdjust == true ? .good : .warn
                )
            }
        }
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "志愿表体检", sub: "以下问题建议调整后再定稿")
            VStack(alignment: .leading, spacing: 5) {
                if !inversions.isEmpty {
                    Text("· 第 \(inversions.map(String.init).joined(separator: "、")) 个志愿存在梯度倒挂（后面的学校更难考），平行志愿会浪费检索位次，建议按等效分从高到低排列。")
                }
                if bao == 0 {
                    Text("· 缺少保底志愿，建议补充 6-12 个等效分低于自身 15 分以上的院校。")
                }
                if state.profile?.obeyAdjust == false {
                    Text("· 未勾选服从专业调剂，一旦分数不够所填专业会被退档，建议勾选。")
                }
                if riskyTop > 0 {
                    Text("· 前 3 个志愿录取概率过低，冲刺可以，但不要把全部希望放在极小概率院校上。")
                }
            }
            .font(.caption).foregroundStyle(Color.ink700)
        }
        .card()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.warn.opacity(0.08)))
    }

    private func employmentCard(_ emp: EmploymentModel.EmploymentAggregate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "志愿表就业结构", sub: "\(emp.count) 个志愿的就业预测聚合，用于检查赛道是否过于集中")
            HStack(spacing: 8) {
                MiniStat(label: "平均落实率", value: "\(emp.avgEmployRate)%", sub: "深造率 \(emp.avgFurtherRate)%")
                MiniStat(label: "平均应届月薪", value: "\(Int(emp.avgSalary))", sub: "5 年 \(Int(emp.avgSalary5y))")
            }
            HStack(spacing: 8) {
                MiniStat(label: "平均就业景气", value: "\(Int(emp.prosperity))", sub: "上升 \(Int(emp.risingShare * 100))%")
                MiniStat(label: "行业集中度", value: "\(Int(emp.concentration))", sub: emp.concentration >= 30 ? "偏高，抗周期弱" : "分散，风险较低")
            }
            MiniStat(label: "承压志愿占比", value: "\(Int(emp.pressedShare * 100))%", sub: "共 \(emp.count) 个志愿")

            Text("整体行业去向").font(.caption2).foregroundStyle(Color.ink400)
            ForEach(emp.industries) { i in ShareRow(name: i.name, pct: i.pct, color: Color.brand) }
            Text("整体就业城市").font(.caption2).foregroundStyle(Color.ink400).padding(.top, 4)
            ForEach(emp.cities) { c in ShareRow(name: c.name, pct: c.pct, color: Color.warn) }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(emp.notes, id: \.self) { t in
                    Text("· \(t)").font(.caption).foregroundStyle(Color.ink700)
                }
            }
            .padding(.top, 4)
        }
        .card()
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.uniName) { i, v in
                let e = evalByName[v.uniName]
                HStack(alignment: .center, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.caption.monospacedDigit())
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.ink50))
                        .foregroundStyle(Color.ink500)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            NavigationLink(value: v.uniName) {
                                Text(v.uniName).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink900)
                            }
                            TierTag(tier: v.tier)
                            if e?.rec.inProvince == true {
                                Text("本省").font(.system(size: 10)).foregroundStyle(Color.ink400)
                            }
                        }
                        let empItem = EmploymentModel.forecast(name: v.uniName, state.dataset)
                        Text(rowSub(e: e, emp: empItem))
                            .font(.caption2).foregroundStyle(Color.ink400)
                        let majors = majorInfo(v.uniName)
                        if let majors {
                            Text(majors)
                                .font(.system(size: 10))
                                .foregroundStyle(majors.contains("无可报") ? Color.danger : Color.good)
                        }
                        if let note = v.note, !note.isEmpty {
                            Text(note).font(.system(size: 10)).foregroundStyle(Color.brand)
                        }
                        ProbBar(prob: v.prob).frame(width: 200)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Button { move(i, -1) } label: {
                            Image(systemName: "chevron.up").font(.caption)
                        }
                        .disabled(i == 0)
                        Button { move(i, 1) } label: {
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .disabled(i == items.count - 1)
                        Button { state.removeVolunteer(v.uniName) } label: {
                            Image(systemName: "xmark").font(.caption).foregroundStyle(Color.danger)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.ink500)
                }
                .padding(.vertical, 10)
                if i < items.count - 1 { Divider() }
            }
        }
        .card()
    }

    /// 导入了专业录取线时，标注该志愿的可报专业数（按考生选科过滤）
    private func majorInfo(_ uniName: String) -> String? {
        let evals = state.majorEvals(uniName)
        guard !evals.isEmpty else { return nil }
        let ok = evals.filter { $0.meets }
        guard !ok.isEmpty else { return "无可报专业（\(evals.count) 个专业均不符合选科）" }
        let safe = ok.filter { $0.prob >= 0.45 }.count
        let top = ok[0]
        return "可报专业 \(ok.count)/\(evals.count) 个 · 稳妥 \(safe) 个 · 最稳 \(top.major.majorName) \(Int(top.prob * 100))%"
    }

    private func rowSub(e: Evaluated?, emp: EmploymentForecast?) -> String {
        var text = e.map { "\($0.rec.seed.city) · \($0.rec.seed.level) · 等效分 \(Int($0.rec.equivScore))" } ?? "数据已更新"
        if let emp { text += " · 就业景气 \(Int(emp.prosperity)) · 5 年 \(Int(emp.salary5y / 1000))k" }
        return text
    }

    private func move(_ i: Int, _ dir: Int) {
        let j = i + dir
        guard j >= 0, j < items.count else { return }
        state.moveVolunteer(from: IndexSet(integer: i), to: j > i ? j + 1 : j)
    }
}
