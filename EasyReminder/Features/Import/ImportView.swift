import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var viewModel: ImportViewModel
    @State private var showingPicker = false
    @State private var dropTargeted = false
    #if os(iOS)
    @State private var showingChangelog = false
    #endif

    init(viewModel: ImportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("导入 ICS 到提醒事项 / 日历")
                    .font(.headline)

                Text("待办（VTODO）进「提醒事项」，日历事件（VEVENT）进「日历」")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("选择 .ics 文件导入（可多选）") { showingPicker = true }
                    .buttonStyle(.borderedProminent)

                Text(viewModel.status)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                #if os(iOS)
                // iOS 没有 macOS 的底部信息栏：版本 / 更新日志入口放这里
                HStack(spacing: 12) {
                    Text(AppInfo.copyright)
                    Button("v\(AppInfo.version)") { showingChangelog = true }
                    Link("GitHub", destination: URL(string: "https://github.com/Jason25417/EasyReminder/releases/latest")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                #endif
            }
            .frame(maxWidth: 480)   // 大屏（13 吋 iPad / 宽窗口）内容不散架
            .frame(maxWidth: .infinity)
            .padding(40)
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 240)
        #endif
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(8)
            }
        }
        // 从 Finder / 「文件」拖 .ics 进窗口。
        // 不能用 URL.self：iOS 的 Files 拖拽只提供文件表示（没有 public.file-url 数据），
        // URL.self 的放置会静默失效——DroppedICSFile 两种表示都接
        .dropDestination(for: DroppedICSFile.self) { files, _ in
            guard !files.isEmpty else { return false }
            Task { await viewModel.beginImport(at: files.map(\.url)) }
            return true
        } isTargeted: { dropTargeted = $0 }
        .fileImporter(isPresented: $showingPicker,
                      allowedContentTypes: Self.icsTypes,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                if !urls.isEmpty { Task { await viewModel.beginImport(at: urls) } }
            case .failure(let error):
                viewModel.status = String(localized: "选择文件失败：\(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $viewModel.showingListPrompt) {
            ImportListPromptView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.importSummary) { summary in
            ImportSummaryView(summary: summary)
        }
        #if os(iOS)
        .sheet(isPresented: $showingChangelog) { ChangelogView() }
        #endif
        .confirmationDialog("检测到重复导入", isPresented: $viewModel.showingDuplicatePrompt, titleVisibility: .visible) {
            Button("全部导入") { Task { await viewModel.resolveDuplicate(importAll: true) } }
            Button("只导入新的 \(viewModel.newCount) 条") { Task { await viewModel.resolveDuplicate(importAll: false) } }
            Button("取消", role: .cancel) { viewModel.cancelDuplicate() }
        } message: {
            Text("有 \(viewModel.duplicateCount) 条之前导入过。")
        }
    }

    private static var icsTypes: [UTType] {
        var t: [UTType] = []
        if let ics = UTType(filenameExtension: "ics") { t.append(ics) }
        t.append(.text)
        return t
    }
}

/// 拖放进来的 .ics 文件。
/// iOS（Files 拖拽）走 FileRepresentation：系统给的是临时就地文件，闭包内必须拷走；
/// macOS（Finder 拖拽）走 ProxyRepresentation 的 file-url，Powerbox 自动授权。
struct DroppedICSFile: Transferable {
    let url: URL

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: UTType(filenameExtension: "ics") ?? .data) { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return DroppedICSFile(url: dest)
        }
        ProxyRepresentation(importing: { (url: URL) in DroppedICSFile(url: url) })
    }
}
