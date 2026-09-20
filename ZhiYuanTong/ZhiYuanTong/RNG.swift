import Foundation

/// 与 Web 版一致的确定性伪随机：同一「院校|省份|科类|年份」每次生成结果完全相同
func fnv1a(_ s: String) -> UInt32 {
    var h: UInt32 = 2166136261
    for unit in s.utf16 {
        h ^= UInt32(unit)
        h = h &* 16777619
    }
    return h
}

func mulberry32(_ seed: UInt32) -> () -> Double {
    var a = seed
    return {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a &>> 15)) &* (a | 1)
        t = (t &+ ((t ^ (t &>> 7)) &* (t | 61))) ^ t
        return Double(t ^ (t &>> 14)) / 4294967296.0
    }
}

func seeded(_ key: String) -> () -> Double {
    mulberry32(fnv1a(key))
}

func clamp(_ v: Double, _ min: Double, _ max: Double) -> Double {
    Swift.min(Swift.max(v, min), max)
}

func mean(_ xs: [Double]) -> Double {
    xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
}

func std(_ xs: [Double]) -> Double {
    let m = mean(xs)
    return sqrt(mean(xs.map { ($0 - m) * ($0 - m) }))
}

/// 对齐 JS 的 Math.round（负数 .5 向 +∞ 取整）
func jsRound(_ x: Double) -> Double {
    floor(x + 0.5)
}
