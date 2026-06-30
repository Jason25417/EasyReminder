import SwiftUI
import Sparkle

struct RootView: View {
    let importVM: ImportViewModel
    let exportVM: ExportViewModel
    let updater: SPUUpdater

    @State private var showingChangelog = false

    private let latestReleaseURL = URL(string: "https://github.com/Jason25417/EasyReminder/releases/latest")!

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ImportView(viewModel: importVM)
                    .tabItem { Label("导入", systemImage: "square.and.arrow.down") }
                ExportView(viewModel: exportVM)
                    .tabItem { Label("导出", systemImage: "square.and.arrow.up") }
            }

            Divider()

            HStack(spacing: 12) {
                Text(AppInfo.copyright)
                Button("v\(AppInfo.version)") { showingChangelog = true }
                    .buttonStyle(.link)
                    .help("查看更新日志")
                Button("检查更新…") { updater.checkForUpdates() }
                    .buttonStyle(.link)
                    .help("检查并安装新版本")
                Link("GitHub", destination: latestReleaseURL)
                    .help("在 GitHub 查看最新版本")
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
