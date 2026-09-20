import Foundation
import LocalAuthentication

enum BiometricKind: String {
    case faceID
    case touchID
    case passcode
    case none

    var label: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "触控 ID"
        case .passcode: return "设备密码"
        case .none: return "生物识别"
        }
    }
}

/// 系统级 Face ID / 触控 ID 验证（LocalAuthentication，非 WebView 插件）
enum Biometrics {
    static func availableKind() -> BiometricKind {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // 生物识别不可用时，若设备设有密码仍可用密码解锁
            if (error?.code ?? 0) != LAError.biometryNotEnrolled.rawValue {
                return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) ? .passcode : .none
            }
            return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) ? .passcode : .none
        }
        switch ctx.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .passcode
        }
    }

    /// 拉起系统验证，成功回调 true
    static func authenticate(reason: String = "验证身份后查看你的分数与志愿表") async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用设备密码"
        ctx.localizedCancelTitle = "取消"
        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return ok
        } catch {
            return false
        }
    }
}
