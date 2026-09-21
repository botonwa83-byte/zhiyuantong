import SwiftUI

struct MeView: View {
    @EnvironmentObject var state: AppState

    @State private var editing = false
    @State private var bioOn = LocalStore.shared.isBioLockEnabled
    @State private var bioErr = ""
    @State private var showDelete = false

    private var profile: StudentProfile { state.profile ?? .placeholder }

    private let bioKind = Biometrics.availableKind()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    profileCard
                    dataCard
                    privacyCard
                    sourceCard
                    dangerCard
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("我的")
            .sheet(isPresented: $editing) { EditProfileSheet().environmentObject(state) }
            .alert("删除本机账号数据？", isPresented: $showDelete) {
                Button("删除", role: .destructive) { state.deleteAccount() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除本机的档案与志愿表，官方数据集保留。")
            }
        }
    }

    // MARK: - 卡片

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "考生档案", sub: "\(profile.name.isEmpty ? "考生" : profile.name) · \(profile.phone)")
                Spacer()
                Button("编辑") { editing = true }
                    .font(.subheadline).foregroundStyle(Color.brand)
            }
            HStack(spacing: 8) {
                MiniStat(label: "省份 / 科类", value: "\(state.prov.name) \(trackLabel(profile.track, state.prov.mode))")
                MiniStat(label: "分数", value: "\(Int(profile.score))", sub: profile.rank.map { "位次 \(Int($0))" } ?? "位次按一分一段换算")
            }
            HStack(spacing: 8) {
                MiniStat(label: "意向城市", value: profile.cities.isEmpty ? "未设置" : profile.cities.joined(separator: "、"))
                MiniStat(label: "意向学科", value: profile.majors.isEmpty ? "未设置" : profile.majors.joined(separator: "、"))
            }
            if state.prov.mode != .old {
                MiniStat(
                    label: "选考科目",
                    value: profile.subjects.isEmpty ? "未设置（不按选科过滤）" : profile.subjects.joined(separator: "/"),
                    sub: profile.subjects.isEmpty ? "设置后可按专业选科要求过滤" : "内置专业录取线的省份生效"
                )
            }
            MiniStat(label: "服从专业调剂", value: profile.obeyAdjust ? "已勾选" : "未勾选", sub: profile.obeyAdjust ? "退档风险低" : "建议勾选以降低退档风险")
        }
        .card()
    }

    /// 数据覆盖：内置的一分一段表 / 投档线按考生高考省份自动匹配，无需导入或校准
    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "数据覆盖", sub: "随 App 内置 · 按高考省份自动匹配")
            let c = state.coverage
            if c.isEmpty {
                Text("\(state.prov.name) 的录取数据尚未内置，测算暂用内置推算模型；该省数据会在后续版本补齐。")
                    .font(.caption).foregroundStyle(Color.ink500)
            } else {
                let years = c.years.map(String.init).joined(separator: " / ")
                Text("\(state.prov.name) · \(years) 年：一分一段 \(c.points) 个分数点 · 投档线 \(c.admissions) 条"
                     + (c.majors > 0 ? " · 专业录取线 \(c.majors) 条" : ""))
                    .font(.caption).foregroundStyle(Color.ink500)
                Text("数据来自各省教育考试院公开信息，随 App 版本更新；不需要手动导入，也不需要校准批次线。")
                    .font(.caption2).foregroundStyle(Color.ink400)
            }
            // 老版本留下的手动校准值：清掉，回到官方数据
            if state.profile?.linesOverride != nil {
                Button {
                    state.update { $0.linesOverride = nil }
                } label: {
                    Text("清除旧版手填批次线，改用官方数据")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandSoft))
                        .foregroundStyle(Color.brand)
                }
            }
        }
        .card()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "数据与隐私", sub: "账号、分数与志愿表只保存在本机，不上传服务器")
            VStack(alignment: .leading, spacing: 6) {
                bullet("全部计算在本机完成，无网络请求、无账号体系")
                bullet("志愿表与官方数据集保存在本机沙盒，卸载 App 即清除")
                bullet("Face ID 仅用于本机解锁，不采集、不存储生物特征")
            }
            .font(.caption).foregroundStyle(Color.ink700)

            if bioKind != .none {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(bioKind.label)解锁").font(.caption.weight(.medium))
                        Text("开启后，每次打开 App 或从后台返回都需要验证")
                            .font(.caption2).foregroundStyle(Color.ink400)
                    }
                    Spacer()
                    Toggle("", isOn: $bioOn)
                        .labelsHidden()
                        .onChange(of: bioOn) { newValue in
                            Task {
                                if newValue {
                                    let ok = await Biometrics.authenticate(reason: "验证身份以开启\(bioKind.label)解锁")
                                    if ok {
                                        LocalStore.shared.isBioLockEnabled = true
                                        bioErr = ""
                                    } else {
                                        LocalStore.shared.isBioLockEnabled = false
                                        bioOn = false
                                        bioErr = "验证未通过，未开启解锁"
                                    }
                                } else {
                                    LocalStore.shared.isBioLockEnabled = false
                                }
                            }
                        }
                }
                if !bioErr.isEmpty { Text(bioErr).font(.caption2).foregroundStyle(Color.danger) }
            }
        }
        .card()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("·")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "数据来源说明", sub: "请以省考试院公布数据为准")
            Text("省份批次线、一分一段表与院校投档线为各省教育考试院公开信息整理所得，随 App 版本更新；正式填报请以省考试院公布的《一分一段表》《招生计划》与院校招生章程为准。就业数据为按学科门类与城市景气度构建的中位数模型，用于横向比较，不代表任何院校的官方就业质量报告。")
                .font(.caption).foregroundStyle(Color.ink700)
        }
        .card()
    }

    private var dangerCard: some View {
        VStack(spacing: 10) {
            Button {
                state.logout()
            } label: {
                Text("退出登录")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))
                    .foregroundStyle(Color.ink700)
            }
            Button {
                showDelete = true
            } label: {
                Text("删除本机账号数据")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.danger.opacity(0.1)))
                    .foregroundStyle(Color.danger)
            }
        }
    }
}

// MARK: - 档案编辑

private struct EditProfileSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var provId = ""
    @State private var track: Track = .phy
    @State private var scoreText = ""
    @State private var rankText = ""
    @State private var cities: [String] = []
    @State private var majors: [String] = []
    @State private var subjects: [String] = []
    @State private var obey = true

    /// 当前所选省份的考试模式：3+3 不分科类，隐藏科类选择器
    private var currentMode: ExamMode {
        DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312
    }

    /// 可选科目：3+1+2 的首选科目由科类决定（物理类=物理、历史类=历史），不重复选；3+3 六门全选；老高考无选科
    private var subjectOptions: [String] {
        guard currentMode != .old else { return [] }
        if currentMode == .t33 { return GAOKAO_SUBJECTS }
        return GAOKAO_SUBJECTS.filter { $0 != (track == .phy ? "物理" : "历史") }
    }

    private var trackSubject: String? {
        currentMode == .t312 ? (track == .phy ? "物理" : "历史") : nil
    }

    private var footerText: String {
        switch currentMode {
        case .t33: return "3+3：勾选你选考的三门；有内置专业录取线时按选科要求过滤专业"
        case .old: return ""
        case .t312:
            return "3+1+2：首选科目「\(trackSubject ?? "")」由科类决定，这里勾选两门再选科目；有内置专业录取线时按选科要求过滤专业"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("姓名 / 昵称", text: $name)
                    Picker("高考省份", selection: $provId) {
                        ForEach(DataStore.shared.provinces) { p in Text(p.name).tag(p.id) }
                    }
                    .onChange(of: provId) { _ in
                        if currentMode == .t33 { track = .phy }
                    }
                    if currentMode != .t33 {
                        Picker("科类", selection: $track) {
                            Text(trackLabel(.phy, currentMode)).tag(Track.phy)
                            Text(trackLabel(.his, currentMode)).tag(Track.his)
                        }
                    }
                    TextField("高考分数", text: $scoreText).numKeyboard(.decimal)
                    TextField("省内位次（可留空自动估算）", text: $rankText).numKeyboard(.integer)
                }
                Section("意向城市") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DataStore.shared.cityCareers) { c in
                                Chip(title: c.name, active: cities.contains(c.name)) {
                                    cities = cities.contains(c.name) ? cities.filter { $0 != c.name } : cities + [c.name]
                                }
                            }
                        }
                    }
                }
                Section("意向学科门类") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DataStore.shared.majorCareers) { m in
                                Chip(title: m.name, active: majors.contains(m.name)) {
                                    majors = majors.contains(m.name) ? majors.filter { $0 != m.name } : majors + [m.name]
                                }
                            }
                        }
                    }
                }
                if !subjectOptions.isEmpty {
                    Section(header: Text("选考科目"), footer: Text(footerText)) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(subjectOptions, id: \.self) { s in
                                    Chip(title: s, active: subjects.contains(s)) {
                                        subjects = subjects.contains(s) ? subjects.filter { $0 != s } : subjects + [s]
                                    }
                                }
                            }
                        }
                    }
                }
                Section("填报偏好") {
                    Toggle("服从专业调剂", isOn: $obey)
                }
            }
            .navigationTitle("编辑档案")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                let p = state.profile ?? .placeholder
                name = p.name
                provId = p.provId
                track = p.track
                scoreText = String(format: "%.0f", p.score)
                rankText = p.rank.map { String(format: "%.0f", $0) } ?? ""
                cities = p.cities
                majors = p.majors
                subjects = p.subjects.filter { !subjectOptions.isEmpty && subjectOptions.contains($0) }
                obey = p.obeyAdjust
            }
        }
    }

    private func save() {
        let score = Double(scoreText) ?? 0
        let rank = Double(rankText)
        state.update { p in
            p.name = name
            p.provId = provId
            p.track = track
            p.score = score
            p.rank = rank
            p.cities = cities
            p.majors = majors
            // 首选科目由科类决定，补全进去，专业选科校验才完整
            p.subjects = Array(Set(subjects + [trackSubject].compactMap { $0 })).sorted { (GAOKAO_SUBJECTS.firstIndex(of: $0) ?? 9) < (GAOKAO_SUBJECTS.firstIndex(of: $1) ?? 9) }
            p.obeyAdjust = obey
        }
    }
}
