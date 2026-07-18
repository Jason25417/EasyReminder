import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var viewModel: ImportViewModel
    @State private var showingPicker = false

    init(viewModel: ImportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("ICS 导入到提醒事项")
                .font(.headline)

            Button("选择 .ics 文件导入（可多选）") { showingPicker = true }
                .buttonStyle(.borderedProminent)

            Text(viewModel.status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(40)
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 240)
        #endif
        .fileImporter(isPresented: $showingPicker,
                      allowedContentTypes: Self.icsTypes,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                if !urls.isEmpty { Task { await viewModel.beginImport(at: urls) } }
            case .failure(let error):
                viewModel.status = "选择文件失败：\(error.localizedDescription)"
            }
        }
        .onOpenURL { url in
            Task { await viewModel.beginImport(at: url) }
        }
        .sheet(isPresented: $viewModel.showingListPrompt) {
            ImportListPromptView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.importSummary) { summary in
            ImportSummaryView(summary: summary)
        }
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
