import SwiftUI

struct RootView: View {
    let importVM: ImportViewModel
    let exportVM: ExportViewModel

    @State private var showingChangelog = false

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ImportView(viewModel: importVM)
                    .tabItem { Label("导入", systemImage: "square.and.arrow.down") }
                ExportView(viewModel: exportVM)
                    .tabItem { Label("导出", systemImage: "square.and.arrow.up") }
            }

            Divider()

            HStack(spacing: 4) {
                Text(AppInfo.copyright)
                Button("v\(AppInfo.version)") { showingChangelog = true }
                    .buttonStyle(.link)
                    .help("查看更新日志")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 520, minHeight: 420)
        .sheet(isPresented: $showingChangelog) { ChangelogView() }
    }
}
