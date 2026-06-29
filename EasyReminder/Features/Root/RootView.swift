import SwiftUI

struct RootView: View {
    let importVM: ImportViewModel
    let exportVM: ExportViewModel
    let updateVM: UpdateViewModel

    @Environment(\.openURL) private var openURL
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
                if let v = updateVM.availableVersion, let url = updateVM.releaseURL {
                    Button("有新版 v\(v) ↗") { openURL(url) }
                        .buttonStyle(.link)
                        .help("打开下载页")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 520, minHeight: 420)
        .task { await updateVM.check() }
        .sheet(isPresented: $showingChangelog) { ChangelogView() }
    }
}
