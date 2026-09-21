import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.profile == nil {
                AuthView()
            } else {
                TabView(selection: $state.tab) {
                    HomeView()
                        .tabItem { Label("概览", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(AppState.AppTab.home)
                    ExploreView()
                        .tabItem { Label("院校推荐", systemImage: "magnifyingglass") }
                        .tag(AppState.AppTab.explore)
                    MyListView()
                        .tabItem { Label("志愿表", systemImage: "list.bullet.rectangle") }
                        .tag(AppState.AppTab.list)
                    CareerView()
                        .tabItem { Label("就业洞察", systemImage: "briefcase") }
                        .tag(AppState.AppTab.career)
                    MeView()
                        .tabItem { Label("我的", systemImage: "person") }
                        .tag(AppState.AppTab.me)
                }
            }
        }
        .overlay {
            if state.locked { LockView() }
        }
        .overlay(alignment: .top) {
            // 内置数据装载与全量匹配在后台线程跑，这里给个提示，避免首屏看起来像卡住
            if state.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在装载\(state.prov.name)官方数据…")
                        .font(.caption)
                        .foregroundStyle(Color.ink500)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.surface))
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - 建档 / 登录

struct AuthView: View {
    @EnvironmentObject var state: AppState

    @State private var phone = ""
    @State private var name = ""
    @State private var provId = DataStore.shared.provinces[0].id
    @State private var track: Track = .phy
    @State private var scoreText = "600"

    /// 当前所选省份的考试模式：3+3 不分科类，隐藏科类选择器
    private var currentMode: ExamMode {
        DataStore.shared.provinces.first { $0.id == provId }?.mode ?? .t312
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("志愿通")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Color.ink900)
                        Text("分数定位 · 冲稳保测算 · 就业洞察\n数据只保存在本机，不上传服务器")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink400)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        AuthField(title: "手机号", placeholder: "用于本机识别账号", text: $phone, keyboard: .integer)
                        AuthField(title: "姓名 / 昵称", placeholder: "选填", text: $name)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("高考省份").font(.caption).foregroundStyle(Color.ink500)
                            Picker("高考省份", selection: $provId) {
                                ForEach(DataStore.shared.provinces) { p in
                                    Text(p.name).tag(p.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))
                            .onChange(of: provId) { _ in
                                if currentMode == .t33 { track = .phy }
                            }
                        }

                        if currentMode != .t33 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("科类").font(.caption).foregroundStyle(Color.ink500)
                                Picker("科类", selection: $track) {
                                    Text(trackLabel(.phy, currentMode)).tag(Track.phy)
                                    Text(trackLabel(.his, currentMode)).tag(Track.his)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        AuthField(title: "高考分数", placeholder: "例如 600", text: $scoreText, keyboard: .decimal)
                    }

                    Button {
                        let score = Double(scoreText) ?? 0
                        state.signIn(
                            phone: phone.isEmpty ? "local" : phone,
                            name: name.isEmpty ? "考生" : name,
                            provId: provId, track: track, score: score
                        )
                    } label: {
                        Text("开始测算")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.brand))
                            .foregroundStyle(Color.white)
                    }
                    .disabled((Double(scoreText) ?? 0) <= 0)

                    Text("首次进入会自动建档；正式填报请以各省教育考试院公布数据为准。")
                        .font(.caption2)
                        .foregroundStyle(Color.ink400)
                }
                .padding(18)
            }
            .background(Color.ink50.opacity(0.6))
        }
    }
}

struct AuthField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var keyboard: NumKeyboard = .plain

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Color.ink500)
            TextField(placeholder, text: $text)
                .numKeyboard(keyboard)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))
        }
    }
}

// MARK: - Face ID 解锁

struct LockView: View {
    @EnvironmentObject var state: AppState
    @State private var message = ""

    private let kind = Biometrics.availableKind()

    var body: some View {
        ZStack {
            Color.surface.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: kind == .faceID ? "faceid" : "lock.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.brand)
                Text("应用已锁定").font(.headline)
                Text("验证身份后查看你的分数与志愿表")
                    .font(.caption)
                    .foregroundStyle(Color.ink400)
                Button {
                    Task {
                        let ok = await Biometrics.authenticate()
                        if ok { state.locked = false } else { message = "验证未通过，请重试" }
                    }
                } label: {
                    Text("使用\(kind.label)解锁")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.brand))
                        .foregroundStyle(Color.white)
                }
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(Color.danger)
                }
            }
        }
        .task {
            guard LocalStore.shared.isBioLockEnabled else { return }
            let ok = await Biometrics.authenticate()
            if ok { state.locked = false }
        }
    }
}
