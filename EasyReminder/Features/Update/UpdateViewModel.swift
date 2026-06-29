import Foundation
import Observation

@MainActor
@Observable
final class UpdateViewModel {
    /// 有更新可用时为新版本号（如 "1.1"），否则 nil。
    var availableVersion: String?
    /// 对应的 GitHub Release 页面，供「下载新版」跳转。
    var releaseURL: URL?

    private let service: UpdateService

    init(service: UpdateService) { self.service = service }

    /// 启动时静默检查一次：仅当远端版本比当前 App 新时，才点亮提示；失败不打扰。
    func check() async {
        guard let release = await service.latestRelease() else { return }
        if isVersion(AppInfo.version, olderThan: release.version) {
            availableVersion = release.version
            releaseURL = release.url
        }
    }
}
