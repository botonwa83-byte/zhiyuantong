import SwiftUI

@main
struct ZhiYuanTongApp: App {
    @StateObject private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var wentBackground = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .onChange(of: scenePhase) { phase in
                    // 只有真正切到后台再回前台才重新上锁：Face ID 弹窗只让 App 进入 inactive，不会误触发
                    if phase == .background {
                        wentBackground = true
                    } else if phase == .active, wentBackground {
                        wentBackground = false
                        if LocalStore.shared.isBioLockEnabled { state.locked = true }
                    }
                }
        }
    }
}
