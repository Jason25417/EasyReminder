import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

struct RootView: View {
    let importVM: ImportViewModel
    let exportVM: ExportViewModel
    #if canImport(Sparkle)
    let updater: SPUUpdater
    #endif

    @State private var selectedTab = 0
    @State private var showingChangelog = false

    private let latestReleaseURL = URL(string: "https://github.com/Jason25417/EasyReminder/releases/latest")!

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                ImportView(viewModel: importVM)
                    .tabItem { Label("导入", systemImage: "square.and.arrow.down") }
                    .tag(0)
                ExportView(viewModel: exportVM)
                    .tabItem { Label("导出", systemImage: "square.and.arrow.up") }
                    .tag(1)
            }

            // 信息栏只在 macOS 有意义；iOS 上会被挤到系统标签栏下面，版本入口移进导入页
            #if os(macOS)
            Divider()

            HStack(spacing: 12) {
                Text(AppInfo.copyright)
                Button("v\(AppInfo.version)") { showingChangelog = true }
                    .buttonStyle(.link)
                    .help("查看更新日志")
                #if canImport(Sparkle)
                Button("检查更新…") { updater.checkForUpdates() }
                    .buttonStyle(.link)
                    .help("检查并安装新版本")
                #endif
                Link("GitHub", destination: latestReleaseURL)
                    .help("在 GitHub 查看最新版本")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif
        .sheet(isPresented: $showingChangelog) { ChangelogView() }
        // 打开 .ics（Open With / 共享表单）：挂在根视图上，且无论停在哪个标签都先切回导入页——
        // 之前挂在 ImportView 里，App 驻留在导出页时打开文件会没反应或弹错页
        .onOpenURL { url in
            selectedTab = 0
            Task { await importVM.beginImport(at: url) }
        }
    }
}
