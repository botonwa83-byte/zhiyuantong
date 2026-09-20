import SwiftUI
import UniformTypeIdentifiers

/// 官方数据接入：粘贴或选择 CSV/TXT，导入后覆盖内置模型
struct DataImportView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .rank
    @State private var text = ""
    @State private var report: ImportReport?
    @State private var showFilePicker = false

    enum Kind: String, CaseIterable, Identifiable {
        case rank, admission, major, employment
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rank: return "一分一段表"
            case .admission: return "院校投档线"
            case .major: return "专业录取线"
            case .employment: return "就业质量报告"
            }
        }
    }

    private var ctx: ImportContext {
        ImportContext(
            provId: state.profile?.provId ?? DataStore.shared.provinces[0].id,
            year: DataStore.shared.currentYear,
            track: state.profile?.track ?? .phy
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statsCard
                    picker
                    editorCard
                    if let report { reportCard(report) }
                    templateCard
                }
                .padding(14)
            }
            .background(Color.ink50.opacity(0.6))
            .navigationTitle("官方数据接入")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let s = try? String(contentsOf: url, encoding: .utf8) { text = s }
                case .failure:
                    break
                }
            }
        }
    }

    private var statsCard: some View {
        let s = state.stats
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "当前数据集", sub: "同一「省份 + 年份 + 科类」重复导入会覆盖旧数据")
            HStack(spacing: 8) {
                MiniStat(label: "一分一段表", value: "\(s.tables)", sub: "\(s.points) 个分数点")
                MiniStat(label: "投档线", value: "\(s.admissions)", sub: "\(s.unis) 所院校")
            }
            HStack(spacing: 8) {
                MiniStat(label: "就业质量报告", value: "\(s.employments)")
                MiniStat(label: "专业录取线", value: "\(s.majors)", sub: "专业级")
            }
            if state.hasOfficialData {
                Button {
                    state.clearDataset()
                    report = ImportReport(ok: true, rows: 0, messages: ["已清除本机官方数据集，恢复内置示例模型"])
                } label: {
                    Text("清除官方数据集")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.danger.opacity(0.12)))
                        .foregroundStyle(Color.danger)
                }
            }
        }
        .card()
    }

    private var picker: some View {
        Picker("数据类型", selection: $kind) {
            ForEach(Kind.allCases) { k in Text(k.label).tag(k) }
        }
        .pickerStyle(.segmented)
        .onChange(of: kind) { _ in report = nil }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: kind.label, sub: hint)
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.ink50))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ink200, lineWidth: 1))
            HStack(spacing: 10) {
                Button {
                    text = template
                } label: {
                    Text("填入模板").font(.caption)
                }
                Button {
                    showFilePicker = true
                } label: {
                    Text("从文件导入").font(.caption)
                }
                Spacer()
                Button {
                    runImport()
                } label: {
                    Text("导入")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Color.brand))
                        .foregroundStyle(Color.white)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .card()
    }

    private func reportCard(_ r: ImportReport) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(r.ok ? "导入成功" : "导入失败").font(.subheadline.weight(.semibold))
                .foregroundStyle(r.ok ? Color.good : Color.danger)
            ForEach(r.messages, id: \.self) { m in
                Text("· \(m)").font(.caption).foregroundStyle(Color.ink700)
            }
        }
        .card()
    }

    private var templateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(title: "格式说明", sub: "支持英文逗号 / 制表符 / 分号分隔，首行可为表头")
            Text(formatNote)
                .font(.caption2)
                .foregroundStyle(Color.ink500)
        }
        .card()
    }

    // MARK: - 逻辑

    private var hint: String {
        switch kind {
        case .rank: return "列：分数, 位次（可选 省份 / 年份 / 科类）。导入后位次换算改用真实数据"
        case .admission: return "列：院校名称, 最低分（可选 位次 / 招生计划 / 省份 / 年份 / 科类）"
        case .major: return "列：院校名称, 专业名称, 最低分（可选 最低位次 / 计划数 / 选科要求 / 省份 / 年份 / 科类）。掌上高考等站点请人工复制，不要自动抓取"
        case .employment: return "列：院校名称, 毕业去向落实率, 深造率, 平均月薪, 主要行业"
        }
    }

    private var formatNote: String {
        switch kind {
        case .rank: return "分数,位次\n700,58\n690,150\n680,320"
        case .admission: return "院校名称,省份,科类,年份,最低分,最低位次,招生计划\n郑州大学,河南,物理,2024,590,23000,1250"
        case .major: return "院校名称,专业名称,科类,年份,最低分,最低位次,计划数,选科要求\n郑州大学,计算机科学与技术,物理,2024,612,21000,120,物理+化学"
        case .employment: return "院校名称,届别,毕业去向落实率,深造率,平均月薪,主要行业\n郑州大学,2024,93.2,45.6,7200,先进制造/信息技术/医疗与卫生"
        }
    }

    private var template: String {
        switch kind {
        case .rank: return "分数,位次\n700,58\n690,150\n680,320\n670,640\n660,1200\n650,2100\n640,3600\n630,6000"
        case .admission: return "院校名称,省份,科类,年份,最低分,最低位次,招生计划\n郑州大学,河南,物理,2024,590,23000,1250\n深圳大学,广东,物理,2024,596,24000,900"
        case .major: return "院校名称,专业名称,科类,年份,最低分,最低位次,计划数,选科要求\n郑州大学,计算机科学与技术,物理,2025,612,21000,120,物理+化学\n郑州大学,临床医学,物理,2025,631,9800,60,物理+化学"
        case .employment: return "院校名称,届别,毕业去向落实率,深造率,平均月薪,主要行业\n郑州大学,2024,93.2,45.6,7200,先进制造/信息技术/医疗与卫生"
        }
    }

    private func runImport() {
        switch kind {
        case .rank: report = state.importRank(text, ctx: ctx)
        case .admission: report = state.importAdmission(text, ctx: ctx)
        case .major: report = state.importMajorAdmission(text, ctx: ctx)
        case .employment: report = state.importEmployment(text)
        }
    }
}
