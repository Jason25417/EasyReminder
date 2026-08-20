import SwiftUI
import UniformTypeIdentifiers
import EasyReminderKit

struct ExportView: View {
    @State private var viewModel: ExportViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    init(viewModel: ExportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("从提醒事项 / 日历导出为 ICS")
                .font(.headline)

            // macOS 与 iPad(regular) 横向双栏（目标 | 项目）；iPhone 窄屏竖排。
            paneLayout {
                targetPane
                itemsPane
            }

            HStack(spacing: 12) {
                Button("导出为 ICS…") { Task { await viewModel.prepareExport() } }
                    .buttonStyle(.borderedProminent)
                #if os(iOS)
                // iOS 上「存到文件再自己去分享」太绕：直接给分享入口（隔空投送、信息、邮件…）
                if let text = viewModel.currentExportText() {
                    ShareLink(item: ICSFile(text: text, filename: viewModel.exportFilename),
                              preview: SharePreview(viewModel.exportFilename)) {
                        Label("分享…", systemImage: "square.and.arrow.up")
                    }
                }
                #endif
            }

            Text(viewModel.status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(30)
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 380)
        #endif
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedID) { Task { await viewModel.loadItems() } }
        .onChange(of: viewModel.rangeStart) { Task { await viewModel.loadItems() } }
        .onChange(of: viewModel.rangeEnd) { Task { await viewModel.loadItems() } }
        .fileExporter(isPresented: $viewModel.showingExporter,
                      document: viewModel.document,
                      contentType: Self.icsType,
                      defaultFilename: viewModel.suggestedName) { result in
            viewModel.exportCompleted(result)
        }
    }

    private var paneLayout: AnyLayout {
        #if os(macOS)
        AnyLayout(HStackLayout(alignment: .top, spacing: 24))
        #else
        // iPad / 横屏大 iPhone（regular）也用双栏；紧凑宽度竖排。
        hSizeClass == .regular
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
        #endif
    }

    // 左：导出目标（提醒列表 / 日历 分区）
    private var targetPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("导出目标").font(.subheadline).foregroundStyle(.secondary)
                Picker("导出目标", selection: $viewModel.selectedID) {
                    Section("提醒事项") {
                        ForEach(viewModel.reminderTargets) { target in
                            Text(target.title).tag(Optional(target.id))
                        }
                    }
                    if !viewModel.calendarTargets.isEmpty {
                        Section("日历") {
                            ForEach(viewModel.calendarTargets) { target in
                                Text(target.title).tag(Optional(target.id))
                            }
                        }
                    }
                }
                .labelsHidden()
                #if os(macOS)
                .frame(width: 200)
                #else
                .frame(maxWidth: hSizeClass == .regular ? 280 : .infinity, alignment: .leading)
                #endif
            }

            if viewModel.isCalendarTarget {
                VStack(alignment: .leading, spacing: 6) {
                    Text("时间范围").font(.subheadline).foregroundStyle(.secondary)
                    DatePicker("从", selection: $viewModel.rangeStart, displayedComponents: .date)
                    DatePicker("到", selection: $viewModel.rangeEnd, displayedComponents: .date)
                }
                #if os(macOS)
                .frame(width: 200)
                #endif
            }
        }
    }

    // 右：导出项目（多选）
    private var itemsPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("导出项目").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Toggle("全选", isOn: Binding(
                    get: { viewModel.allSelected },
                    set: { viewModel.setSelectAll($0) }
                ))
                #if os(macOS)
                .toggleStyle(.checkbox)
                .font(.caption)
                #else
                .toggleStyle(.button)
                #endif
                .disabled(viewModel.isCalendarTarget ? viewModel.eventItems.isEmpty : viewModel.items.isEmpty)
            }
            itemList
        }
    }

    private var itemList: some View {
        Group {
            if viewModel.isCalendarTarget ? viewModel.eventItems.isEmpty : viewModel.items.isEmpty {
                ContentUnavailableView(viewModel.isCalendarTarget
                                       ? "这个日历在所选范围内没有事件"
                                       : "这个列表没有提醒",
                                       systemImage: "tray")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.isCalendarTarget {
                            ForEach(viewModel.eventItems) { event in
                                row(id: event.id, title: event.title, subtitle: Self.subtitle(for: event))
                                Divider()
                            }
                        } else {
                            ForEach(viewModel.items) { item in
                                row(id: item.id, title: item.title, subtitle: item.dueDate.map(Self.dateText))
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 260, height: 200)
        #else
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
        #endif
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }

    private func row(id: UUID, title: String, subtitle: String?) -> some View {
        Button {
            viewModel.toggle(id)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: viewModel.isSelected(id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.isSelected(id) ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).lineLimit(2)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .frame(minHeight: Self.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.isSelected(id) ? [.isSelected] : [])
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
    }

    // 触控端行高不低于 44pt（HIG）；桌面保持紧凑
    private static var rowMinHeight: CGFloat? {
        #if os(iOS)
        44
        #else
        nil
        #endif
    }

    private static var icsType: UTType { UTType(filenameExtension: "ics") ?? .text }

    private static func subtitle(for event: EventItem) -> String? {
        guard let start = event.startDate else { return nil }
        var parts: [String] = []
        if event.isAllDay {
            parts.append("\(Self.dayText(start)) · " + String(localized: "全天"))
        } else {
            parts.append(Self.dateText(start))
        }
        if event.recurrence != nil { parts.append(String(localized: "重复")) }
        return parts.joined(separator: " · ")
    }

    private static func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    private static func dayText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
}

#if os(iOS)
/// iOS 分享用的 .ics 临时文件（分享时才落盘）。
private struct ICSFile: Transferable {
    let text: String
    let filename: String

    // Transferable 的协议要求是 nonisolated 的；默认 MainActor 隔离下必须显式标注
    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: UTType(filenameExtension: "ics") ?? .plainText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.filename)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
#endif
