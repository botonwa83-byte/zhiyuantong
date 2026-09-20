import SwiftUI

/**
 * 智能生成志愿表向导（软件核心功能）。
 * 四步：意向城市 → 意向专业 → 服从调剂与梯度策略 → 确认生成。
 * 生成后自动写入志愿表并跳转到「志愿表」页签。
 */
struct GenWizardView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private let steps = ["意向城市", "意向专业", "调剂与策略", "确认生成"]

    @State private var step = 0
    @State private var prefs: Recommend.GenPrefs
    @State private var message = ""

    init(prefs: Recommend.GenPrefs) {
        _prefs = State(initialValue: prefs)
    }

    private var result: Recommend.GenResult {
        Recommend.genVolunteers(state.evals, prefs: prefs, ds: state.engine.dataset)
    }

    private var profile: StudentProfile { state.profile ?? .placeholder }

    var body: some View {
        VStack(spacing: 0) {
            header
            stepBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .background(Color.surface)
    }

    // MARK: - 结构

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("智能生成志愿表").font(.headline).foregroundStyle(Color.ink900)
                Text("\(Int(profile.score)) 分 · \(state.prov.name) · \(profile.track.label) · 位次约 \((state.rank / 10000).rounded(toPlaces: 1)) 万")
                    .font(.caption2).foregroundStyle(Color.ink400)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(Color.ink400)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                Button {
                    if i < step { step = i }
                } label: {
                    Text("\(i + 1). \(s)")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(barColor(i)))
                        .foregroundStyle(barText(i))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func barColor(_ i: Int) -> Color {
        i == step ? Color.brand : i < step ? Color.brandSoft : Color.ink50
    }

    private func barText(_ i: Int) -> Color {
        i == step ? Color.white : i < step ? Color.brand : Color.ink400
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: cityStep
        case 1: majorStep
        case 2: strategyStep
        default: confirmStep
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(Color.ink500).fixedSize(horizontal: false, vertical: true)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundStyle(Color.ink400).fixedSize(horizontal: false, vertical: true)
    }

    private func fieldTitle(_ title: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink900)
            if let sub { Text(sub).font(.caption2).foregroundStyle(Color.ink400) }
        }
    }

    /// 自适应排布的多选标签
    private func chipGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            content()
        }
    }

    private func toggle(in array: [String], _ v: String) -> [String] {
        array.contains(v) ? array.filter { $0 != v } : array + [v]
    }

    // MARK: - 1. 意向城市

    private var cityStep: some View {
        Group {
            note("选择毕业后想去的城市（可多选，不选表示不限）。命中意向城市的院校会在同层次里被优先排进志愿表，其余院校仍会参与冲稳保填充。")
            fieldTitle("意向城市", sub: "已选 \(prefs.cities.count) 个 · 当前分数下有 \(result.pool) 所院校可考虑，其中 \(result.matched) 所命中偏好")
            chipGrid {
                ForEach(DataStore.shared.cityCareers.sorted { $0.prosperity > $1.prosperity }) { c in
                    Chip(title: c.name, active: prefs.cities.contains(c.name)) {
                        prefs.cities = toggle(in: prefs.cities, c.name)
                    }
                }
            }
            HStack(spacing: 14) {
                Button("不限城市") { prefs.cities = [] }
                Button("选景气最高的 3 个") {
                    prefs.cities = DataStore.shared.cityCareers.sorted { $0.prosperity > $1.prosperity }.prefix(3).map(\.name)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.brand)
        }
    }

    // MARK: - 2. 意向专业

    private var majorStep: some View {
        Group {
            note("选择想学的方向，系统会优先挑「王牌专业 / 优势学科」与之重合的院校。同样不选表示不限；门类与热门专业是「或」的关系。")
            fieldTitle("意向学科门类", sub: "已选 \(prefs.disciplines.count) 个门类 · \(prefs.hotMajors.count) 个热门专业")
            chipGrid {
                ForEach(DataStore.shared.majorCareers) { m in
                    Chip(title: m.name, active: prefs.disciplines.contains(m.name)) {
                        prefs.disciplines = toggle(in: prefs.disciplines, m.name)
                    }
                }
            }
            fieldTitle("意向热门专业（细分方向）")
            chipGrid {
                ForEach(DataStore.shared.hotMajors) { m in
                    Chip(title: m.name, active: prefs.hotMajors.contains(m.name)) {
                        prefs.hotMajors = toggle(in: prefs.hotMajors, m.name)
                    }
                }
            }
            Button("不限专业") { prefs.disciplines = []; prefs.hotMajors = [] }
                .font(.caption)
                .foregroundStyle(Color.brand)
        }
    }

    // MARK: - 3. 调剂与策略

    private var strategyStep: some View {
        Group {
            fieldTitle("是否服从专业调剂")
            Picker("是否服从专业调剂", selection: Binding(
                get: { prefs.obeyAdjust ? 0 : 1 },
                set: { prefs.obeyAdjust = ($0 == 0) }
            )) {
                Text("服从（推荐）").tag(0)
                Text("不服从").tag(1)
            }
            .pickerStyle(.segmented)
            note(prefs.obeyAdjust
                ? "推荐：分数够不到所填专业时会被调剂到同校其他专业，极大降低退档风险。"
                : "自选=危险：一旦分数够不到所填专业会被退档，本轮已经掉了该批次所有志愿。")

            let want = Recommend.planCounts(prefs)
            fieldTitle("冲稳保梯度策略", sub: "目标配额：冲 \(want.chong) / 稳 \(want.wen) / 保 \(want.bao)，共 \(want.chong + want.wen + want.bao) 个")
            Picker("冲稳保梯度策略", selection: $prefs.strategy) {
                ForEach(GenStrategy.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            ForEach(GenStrategy.allCases) { s in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.label).font(.caption.weight(.semibold)).foregroundStyle(Color.ink700)
                    Text(s.note).font(.caption2).foregroundStyle(Color.ink400)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))

            fieldTitle("是否优先省内院校")
            Picker("是否优先省内院校", selection: Binding(
                get: { prefs.preferProvince ? 0 : 1 },
                set: { prefs.preferProvince = ($0 == 0) }
            )) {
                Text("优先本省").tag(0)
                Text("不限制").tag(1)
            }
            .pickerStyle(.segmented)
            note("省内同层次院校投放计划通常是外省的 3 倍以上，录取线差平均低 10 分。")
        }
    }

    // MARK: - 4. 确认生成

    private var confirmStep: some View {
        Group {
            VStack(alignment: .leading, spacing: 5) {
                summaryRow("意向城市", prefs.cities.isEmpty ? "不限" : prefs.cities.joined(separator: "、"))
                let majors = prefs.disciplines + prefs.hotMajors
                summaryRow("意向专业", majors.isEmpty ? "不限" : majors.joined(separator: "、"))
                summaryRow(
                    "调剂与策略",
                    "\(prefs.obeyAdjust ? "服从调剂" : "不服从调剂") · \(prefs.strategy.label) · \(prefs.preferProvince ? "优先本省" : "不限省份")"
                )
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))

            HStack(spacing: 8) {
                StatTile(label: "志愿总数", value: "\(result.items.count)")
                StatTile(label: "冲", value: "\(result.chong)", tone: .warn)
                StatTile(label: "稳", value: "\(result.wen)", tone: .brand)
                StatTile(label: "保", value: "\(result.bao)", tone: .good)
            }

            if !state.volunteers.isEmpty {
                Text("生成后会覆盖当前志愿表（现有的 \(state.volunteers.count) 个志愿将被替换）。")
                    .font(.caption2).foregroundStyle(Color.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, w in
                Text(w)
                    .font(.caption).foregroundStyle(Color.ink700)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.warn.opacity(0.12)))
            }

            if result.items.isEmpty {
                hint("当前条件下没有匹配到录取概率≥15% 的院校，建议放宽城市与专业限制，或到「院校推荐」手动挑选。")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    hint("前 6 个志愿预览（完整列表生成后可在志愿表调整顺序）")
                    ForEach(Array(result.items.prefix(6).enumerated()), id: \.element.uniName) { i, v in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("\(i + 1)").font(.caption2.monospacedDigit()).foregroundStyle(Color.ink400)
                                Text(v.uniName).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink900)
                                TierTag(tier: v.tier)
                            }
                            ProbBar(prob: v.prob)
                            if let n = v.note {
                                Text(n).font(.system(size: 10)).foregroundStyle(Color.brand)
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }

            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(Color.danger).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(Color.ink400).frame(width: 64, alignment: .leading)
            Text(value).font(.caption).foregroundStyle(Color.ink900)
        }
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button { step -= 1 } label: {
                    Text("上一步")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink100))
                        .foregroundStyle(Color.ink700)
                }
            }
            Button {
                if step < 3 {
                    step += 1
                } else {
                    generate()
                }
            } label: {
                Text(step < 3 ? "下一步：\(steps[step + 1])" : "生成志愿表并查看")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brand))
                    .foregroundStyle(Color.white)
            }
            .disabled(step == 3 && result.items.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func generate() {
        let res = state.generateVolunteers(prefs: prefs)
        guard !res.items.isEmpty else {
            message = "当前条件下没有匹配到录取概率≥15% 的院校（\(Int(profile.score)) 分 / \(state.prov.name)）。志愿表未被改动，请放宽城市或专业限制。"
            return
        }
        dismiss()
    }
}
