import Charts
import SwiftUI

// MARK: - 设计基元

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static let brand = Color(hex: 0x3563F4)
    /// 卡片底色：iOS 用 systemBackground，macOS 用 windowBackground
    static var surface: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }
    static let brandSoft = Color(hex: 0xEEF2FF)
    static let ink900 = Color(hex: 0x111827)
    static let ink700 = Color(hex: 0x374151)
    static let ink500 = Color(hex: 0x6B7280)
    static let ink400 = Color(hex: 0x9CA3AF)
    static let ink200 = Color(hex: 0xE5E7EB)
    static let ink100 = Color(hex: 0xF3F4F6)
    static let ink50 = Color(hex: 0xF9FAFB)
    static let good = Color(hex: 0x10B981)
    static let warn = Color(hex: 0xF59E0B)
    static let danger = Color(hex: 0xF43F5E)
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}

/// 跨平台数字键盘（macOS 无 UIKeyboardType，直接原样返回）
enum NumKeyboard { case decimal, integer, plain }

extension View {
    @ViewBuilder
    func numKeyboard(_ kind: NumKeyboard) -> some View {
        #if os(iOS)
        switch kind {
        case .decimal: self.keyboardType(.decimalPad)
        case .integer: self.keyboardType(.numberPad)
        case .plain: self
        }
        #else
        self
        #endif
    }

    /// 导航栏标题样式（仅 iOS，macOS 无此 modifier）
    @ViewBuilder
    func inlineNavTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct SectionTitle: View {
    var title: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink900)
            if let sub, !sub.isEmpty {
                Text(sub).font(.caption2).foregroundStyle(Color.ink400)
            }
        }
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var sub: String? = nil
    var tone: Tone = .plain

    enum Tone { case plain, brand, good, warn }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(Color.ink400)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            if let sub, !sub.isEmpty {
                Text(sub).font(.caption2).foregroundStyle(Color.ink400).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
        )
    }

    private var valueColor: Color {
        switch tone {
        case .plain: return Color.ink900
        case .brand: return Color.brand
        case .good: return Color.good
        case .warn: return Color.warn
        }
    }

    private var background: Color {
        switch tone {
        case .plain: return Color.ink50
        case .brand: return Color.brandSoft
        case .good: return Color.good.opacity(0.12)
        case .warn: return Color.warn.opacity(0.14)
        }
    }
}

struct MiniStat: View {
    var label: String
    var value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(Color.ink400)
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Color.ink900)
            if let sub, !sub.isEmpty { Text(sub).font(.system(size: 10)).foregroundStyle(Color.ink400) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ink50))
    }
}

struct TierTag: View {
    var tier: String

    var body: some View {
        Text(tier)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch tier {
        case "保": return Color.good
        case "稳": return Color.brand
        case "冲": return Color.warn
        default: return Color.ink500
        }
    }
}

struct ProbBar: View {
    var prob: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ink100)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(clamp(prob, 0, 1)))
            }
        }
        .frame(height: 6)
    }

    private var color: Color {
        prob >= 0.75 ? Color.good : prob >= 0.45 ? Color.brand : prob >= 0.18 ? Color.warn : Color.ink400
    }
}

struct Chip: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Color.brand : Color.ink50))
                .overlay(Capsule().stroke(active ? Color.brand : Color.ink200, lineWidth: 1))
                .foregroundStyle(active ? Color.white : Color.ink700)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 图表

struct LineSeries: Identifiable {
    var name: String
    var values: [Double]
    var color: Color
    var dashed: Bool = false
    var id: String { name }
}

struct LineChartView: View {
    var labels: [String]
    var series: [LineSeries]
    var height: CGFloat = 190

    var body: some View {
        let data = series.flatMap { s in
            s.values.enumerated().map { (idx, v) in
                (series: s.name, label: labels.indices.contains(idx) ? labels[idx] : "", value: v, color: s.color, dashed: s.dashed)
            }
        }
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { _, d in
                LineMark(
                    x: .value("年份", d.label),
                    y: .value("数值", d.value),
                    series: .value("系列", d.series)
                )
                .foregroundStyle(d.color)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: d.dashed ? [4, 3] : []))
                .symbol(Circle().strokeBorder(lineWidth: 2))
            }
        }
        .chartForegroundStyleScale([
            "特殊类型线": Color.brand, "本科线": Color.good, "本科上线率": Color.warn, "本科录取率": Color.brand,
        ])
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: height)
    }
}

struct BarChartView: View {
    var labels: [String]
    var values: [Double]
    var colors: [Color]? = nil
    var singleColor: Color = Color.brand
    var height: CGFloat = 180
    var fmt: ((Double) -> String)? = nil

    var body: some View {
        Chart {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                let v = values.indices.contains(i) ? values[i] : 0
                BarMark(x: .value("名称", label), y: .value("数值", v))
                    .foregroundStyle(colors?.indices.contains(i) == true ? colors![i] : singleColor)
                    .annotation(position: .top) {
                        if let fmt { Text(fmt(v)).font(.system(size: 9)).foregroundStyle(Color.ink400) }
                    }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 9))
            }
        }
        .frame(height: height)
    }
}

/// 横向占比条（行业 / 城市去向）
struct ShareRow: View {
    var name: String
    var pct: Double
    var color: Color = Color.brand

    var body: some View {
        HStack(spacing: 8) {
            Text(name).font(.caption).foregroundStyle(Color.ink700).frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ink100)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(clamp(pct / 100, 0, 1)))
                }
            }
            .frame(height: 7)
            Text(String(format: "%.1f%%", pct)).font(.caption2).monospacedDigit().foregroundStyle(Color.ink500)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

struct EmptyHint: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.ink400)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
}
