import SwiftUI

struct MeView: View {
    @EnvironmentObject var state: AppState

    @State private var editing = false
    @State private var calibrate = false
    @State private var showImport = false
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
            .sheet(isPresented: $calibrate) { CalibrateSheet().environmentObject(state) }
            .sheet(isPresented: $showImport) { DataImportView().environmentObject(state) }
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
                MiniStat(label: "省份 / 科类", value: "\(state.prov.name) \(profile.track.label)")
                MiniStat(label: "分数", value: "\(Int(profile.score))", sub: profile.rank.map { "位次 \(Int($0))" } ?? "位次估算")
            }
            HStack(spacing: 8) {
                MiniStat(label: "意向城市", value: profile.cities.isEmpty ? "未设置" : profile.cities.joined(separator: "、"))
                MiniStat(label: "意向学科", value: profile.majors.isEmpty ? "未设置" : profile.majors.joined(separator: "、"))
            }
            MiniStat(label: "服从专业调剂", value: profile.obeyAdjust ? "已勾选" : "未勾选", sub: profile.obeyAdjust ? "退档风险低" : "建议勾选以降低退档风险")
        }
        .card()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "官方数据接入", sub: "导入一分一段表 / 投档线 / 专业录取线 / 就业质量报告后，测算改用真实数据")
            let s = state.stats
            Text(state.hasOfficialData
                 ? "已导入：\(s.tables) 张一分一段表（\(s.points) 个分数点）· \(s.admissions) 条投档线 · \(s.majors) 条专业录取线 · \(s.employments) 份就业报告"
                 : "当前使用内置示例模型")
                .font(.caption).foregroundStyle(Color.ink500)
            Button {
                showImport = true
            } label: {
                Text("导入 / 管理官方数据")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brand))
                    .foregroundStyle(Color.white)
            }
            Button {
                calibrate = true
            } label: {
                Text("批次线校准（填入今年官方批次线）")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandSoft))
                    .foregroundStyle(Color.brand)
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
            Text("省份批次线与院校录取数据为公开信息整理后的模型化示例；正式填报请以各省教育考试院公布的《一分一段表》《招生计划》与院校招生章程为准。就业数据为按学科门类与城市景气度构建的中位数模型，导入高校官方就业质量报告后自动替换为真实值。")
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
    @State private var obey = true

    /// 当前所选省份的考试模式：3+3 不分科类，隐藏科类选择器
    private var currentMode: ExamMode {
        DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312
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
            p.obeyAdjust = obey
        }
    }
}

// MARK: - 批次线校准

private struct CalibrateSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var special = ""
    @State private var undergrad = ""
    @State private var college = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("今年官方批次线（留空则用内置值）") {
                    TextField("特殊类型线", text: $special).numKeyboard(.decimal)
                    TextField("本科线", text: $undergrad).numKeyboard(.decimal)
                    TextField("专科线", text: $college).numKeyboard(.decimal)
                }
                Section {
                    Text("填入后，等效分换算与冲稳保分层都以官方线为锚点。")
                        .font(.caption).foregroundStyle(Color.ink500)
                }
            }
            .navigationTitle("批次线校准")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        state.update { p in
                            p.linesOverride = .init(
                                special: Double(special),
                                undergrad: Double(undergrad),
                                college: Double(college)
                            )
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("清除校准") {
                        state.update { $0.linesOverride = nil }
                        dismiss()
                    }
                }
            }
            .onAppear {
                let o = state.profile?.linesOverride
                special = o?.special.map { String(format: "%.0f", $0) } ?? ""
                undergrad = o?.undergrad.map { String(format: "%.0f", $0) } ?? ""
                college = o?.college.map { String(format: "%.0f", $0) } ?? ""
            }
        }
    }
}
