import Charts
import SwiftUI

struct MyListView: View {
    @EnvironmentObject var state: AppState
    @State private var showGen = false
    /// 展开了「可报专业清单」的院校名（内置了专业录取线的省份才有点开的意义）
    @State private var expanded: Set<String> = []

    /// 当前批次的志愿：各省批次分开管理，本科批与专科批互不干扰
    private var items: [VolunteerItem] { state.volunteers.filter { $0.batch == state.currentBatch } }
    /// 该省可填批次（按分数筛过）：为空表示这个省还没有批次规则，退回原来的单表模式
    private var batches: [BatchRuleDTO] { state.availableBatches }
    private var rule: BatchRuleDTO? { batches.first { $0.batchKind.rawValue == state.currentBatch } }
    private var evalByName: [String: Evaluated] {
        var map = Dictionary(uniqueKeysWithValues: state.evals.map { ($0.rec.seed.name, $0) })
        for e in state.batchEvals { map[e.rec.seed.name] = e }
        return map
    }
    private var supplementNote: String? { DataStore.shared.supplementNote(of: state.profile?.provId ?? "") }

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

    /// 志愿数超过该批次上限（多是手动添加时超出）
    private var overQuota: Bool { rule.map { items.count > $0.max } ?? false }

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
                    if !batches.isEmpty { batchPicker }
                    if let rule { batchRuleCard(rule) }
                    if state.currentBatchKind == .earlyUG { earlyGroupCard }
                    statRow

                    if inversions.isEmpty == false || state.profile?.obeyAdjust == false || bao == 0 || riskyTop > 0 || overQuota {
                        checkCard
                    }

                    if let note = supplementNote, !items.isEmpty {
                        supplementCard(note)
                    }

                    if let emp { employmentCard(emp) }

                    if items.isEmpty {
                        EmptyHint(
                            text: batches.isEmpty
                                ? "还没有志愿，点击右上角「一键智能填充」快速生成冲稳保方案"
                                : "「\(rule?.name ?? "本批次")」还没有志愿，点击右上角「一键智能填充」按本批次规则生成"
                        ).card()
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
                            Button("清空本批次", role: .destructive) { state.clearVolunteers() }
                        }
                        let other = state.volunteers.filter { $0.batch != state.currentBatch }
                        if !other.isEmpty {
                            Button("清空全部批次（\(state.volunteers.count) 个）", role: .destructive) {
                                state.clearAllVolunteers()
                            }
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
            if let rule {
                Text("\(rule.name)：\(rule.isSequential ? "顺序志愿按「稳 → 保」排列" : "平行志愿按「冲 → 稳 → 保」从上到下排列")，\(items.count)/\(rule.max) 个")
                    .font(.caption).foregroundStyle(Color.ink400)
            } else {
                Text("平行志愿按「冲 → 稳 → 保」从上到下排列，共 \(items.count) 个")
                    .font(.caption).foregroundStyle(Color.ink400)
            }
        }
    }

    // MARK: - 批次

    /// 批次切换：各省可填的批次（本科线下只剩专科批次），点一个切一个
    private var batchPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(batches) { r in
                    Button {
                        state.selectBatch(r.batchKind)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name)
                                .font(.system(size: 12, weight: .medium))
                            Text("\(state.volunteers.filter { $0.batch == r.batchKind.rawValue }.count)/\(r.max) 个")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(state.currentBatch == r.batchKind.rawValue ? Color.brand : Color.surface)
                        )
                        .foregroundStyle(state.currentBatch == r.batchKind.rawValue ? Color.white : Color.ink700)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(state.currentBatch == r.batchKind.rawValue ? Color.brand : Color.ink100, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 批次规则卡：志愿数上限、平行或顺序、有没有专业调剂、规则是否已核对
    private func batchRuleCard(_ r: BatchRuleDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink900)
                Text(r.isSequential ? "顺序志愿" : "平行志愿")
                    .font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                Text(r.isGroupUnit ? "院校专业组" : "专业+学校")
                    .font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.ink50)).foregroundStyle(Color.ink500)
                Spacer()
                Text("\(items.count)/\(r.max)").font(.caption.monospacedDigit()).foregroundStyle(Color.ink400)
            }
            Text(ruleText(r))
                .font(.caption2).foregroundStyle(Color.ink500)
                .fixedSize(horizontal: false, vertical: true)
            if let note = r.note {
                Text(note).font(.caption2).foregroundStyle(Color.ink400).fixedSize(horizontal: false, vertical: true)
            }
            if !r.verified {
                Text("该批次的志愿数上限尚未与当年官方文件逐条核对，正式填报请以省考试院公告为准。")
                    .font(.caption2).foregroundStyle(Color.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func ruleText(_ r: BatchRuleDTO) -> String {
        var parts = ["本批次最多可填 \(r.max) 个志愿"]
        if r.isGroupUnit {
            parts.append("每个志愿是「一所院校的一个专业组」，组内最多 \(r.majorsPerVolunteer) 个专业，可勾选专业调剂")
        } else {
            parts.append("每个志愿就是一个具体专业，没有专业调剂，填的每个专业都必须能接受")
        }
        if r.isSequential {
            parts.append("顺序（梯度）志愿第一志愿优先，冲高失败会大幅掉档")
        }
        return parts.joined(separator: "；") + "。"
    }

    /// 提前批：各类别不得兼报
    private var earlyGroupCard: some View {
        let groups = DataStore.shared.batches(of: state.profile?.provId ?? "")?.earlyGroups ?? []
        return VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "提前批类别", sub: "只能选报其中一类")
            if groups.isEmpty {
                Text("· 各省提前批一般分军事、公安、司法、师范、医学等类别，各类别不得兼报，且多数需要体检、政审或面试。")
                    .font(.caption).foregroundStyle(Color.ink700)
            } else {
                Text("· " + groups.joined(separator: "、") + "：只能选报其中一类（各省规定略有差异）。")
                    .font(.caption).foregroundStyle(Color.ink700)
            }
            Text("· 提前批被录取后，后面本科批的志愿自动作废；没被录取则不影响后续批次。")
                .font(.caption).foregroundStyle(Color.ink700)
        }
        .card()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.warn.opacity(0.08)))
    }

    /// 征集志愿（补录）提醒：投档线数据里没有征集志愿，只能提示考生盯公告
    private func supplementCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "征集志愿（补录）", sub: "本 App 无征集计划数据")
            Text(note).font(.caption).foregroundStyle(Color.ink700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.brandSoft.opacity(0.5)))
    }

    private var statRow: some View {
        let quota = rule.map {
            tierQuota(max: $0.max, strategy: state.profile?.strategy ?? .balanced, sequential: $0.isSequential)
        }
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(label: "志愿总数", value: "\(items.count)", sub: rule.map { "上限 \($0.max) 个" } ?? "建议 30-45 个")
                StatTile(
                    label: "冲 / 稳 / 保",
                    value: "\(chong) / \(wen) / \(bao)",
                    sub: quota.map { "建议 \($0.reach) / \($0.match) / \($0.safe)" } ?? "建议 12 / 18 / 12"
                )
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
                    value: rule?.allowAdjust == false ? "无此选项" : (state.profile?.obeyAdjust == true ? "已勾选" : "未勾选"),
                    sub: rule?.allowAdjust == false ? "专业+学校模式不退档" : (state.profile?.obeyAdjust == true ? "退档风险低" : "退档风险上升"),
                    tone: rule?.allowAdjust == false ? .brand : (state.profile?.obeyAdjust == true ? .good : .warn)
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
                if state.profile?.obeyAdjust == false && rule?.allowAdjust != false {
                    Text("· 未勾选服从专业调剂，一旦分数不够所填专业会被退档，建议勾选。")
                }
                if overQuota, let r = rule {
                    Text("· 本批次志愿数 \(items.count) 个已超过 \(r.max) 个上限，正式填报系统会拒绝录入超出的部分，建议删除或移到其他批次。")
                }
                if rule?.isSequential == true && chong > 0 {
                    Text("· 这是顺序（梯度）志愿，第一志愿优先，冲 \(chong) 个高风险志愿会浪费第一志愿，建议把把握最大的院校放在第一位。")
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
                        let evals = state.majorEvals(v.uniName)
                        if !evals.isEmpty {
                            majorDisclosure(v.uniName, evals: evals)
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
                        Button { state.removeVolunteer(v.uniName, batch: v.batch) } label: {
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

    /// 内置了专业录取线时，标注该志愿的可报专业数（按考生选科过滤），点开可看专业级概率
    private func majorDisclosure(_ uniName: String, evals: [MajorEval]) -> some View {
        let ok = evals.filter(\.meets)
        let open = expanded.contains(uniName)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if open { expanded.remove(uniName) } else { expanded.insert(uniName) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.ink400)
                    Text(majorSummary(ok: ok, total: evals.count))
                        .font(.system(size: 10))
                        .foregroundStyle(ok.isEmpty ? Color.danger : Color.good)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(evals.prefix(12))) { ev in
                        HStack(alignment: .center, spacing: 6) {
                            Text(ev.major.majorName)
                                .font(.caption)
                                .foregroundStyle(ev.meets ? Color.ink900 : Color.ink400)
                            if !ev.meets {
                                Text("选科不符")
                                    .font(.system(size: 9)).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.danger.opacity(0.12))).foregroundStyle(Color.danger)
                            } else if let req = ev.major.subjectReq, !req.isEmpty {
                                Text(req)
                                    .font(.system(size: 9)).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.brandSoft)).foregroundStyle(Color.brand)
                            }
                            Spacer()
                            if ev.meets { TierTag(tier: ev.tier) }
                            Text("\(Int(ev.prob * 100))%")
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(ev.prob >= 0.45 ? Color.good : Color.warn)
                        }
                        Text("等效分 \(Int(ev.equivScore))"
                             + " · 你\(ev.gap >= 0 ? "高出" : "低")\(Int(abs(ev.gap.rounded()))) 分"
                             + (ev.major.plan.map { " · 计划 \(Int($0)) 人" } ?? ""))
                            .font(.system(size: 10)).foregroundStyle(Color.ink400)
                    }
                    if evals.count > 12 {
                        Text("仅显示概率最高的 12 个专业，完整清单见院校详情")
                            .font(.system(size: 10)).foregroundStyle(Color.ink400)
                    }
                    Text("专业按录取概率排序；实际填报时把更想去的专业写在前面（专业优先省份尤其重要），并确认勾选服从调剂。")
                        .font(.system(size: 10)).foregroundStyle(Color.ink400)
                }
                .padding(.leading, 12)
                .transition(.opacity)
            }
        }
    }

    private func majorSummary(ok: [MajorEval], total: Int) -> String {
        guard !ok.isEmpty else { return "无可报专业（\(total) 个专业均不符合选科）" }
        let safe = ok.filter { $0.prob >= 0.45 }.count
        let top = ok[0]
        return "可报专业 \(ok.count)/\(total) 个 · 稳妥 \(safe) 个 · 最稳 \(top.major.majorName) \(Int(top.prob * 100))%"
    }

    private func rowSub(e: Evaluated?, emp: EmploymentForecast?) -> String {
        var text = e.map { "\($0.rec.seed.city) · \($0.rec.seed.level) · 等效分 \(Int($0.rec.equivScore))" } ?? "数据已更新"
        if let emp { text += " · 就业景气 \(Int(emp.prosperity)) · 5 年 \(Int(emp.salary5y / 1000))k" }
        return text
    }

    private func move(_ i: Int, _ dir: Int) {
        let j = i + dir
        guard j >= 0, j < items.count else { return }
        state.moveVolunteer(inBatch: state.currentBatch, from: IndexSet(integer: i), to: j > i ? j + 1 : j)
    }
}
