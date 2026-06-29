import Foundation

/// 通过 GitHub Releases API 查询最新版本。
/// 任何失败（无 Release 返回 404、断网、解析失败）都静默返回 nil。
struct GitHubUpdateService: UpdateService {
    private let owner = "Jason25417"
    private let repo = "EasyReminder"

    private struct LatestRelease: Decodable {
        let tagName: String
        let htmlURL: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    func latestRelease() async -> AppRelease? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("EasyReminder", forHTTPHeaderField: "User-Agent")   // GitHub API 必需，否则 403
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let release = try JSONDecoder().decode(LatestRelease.self, from: data)
            let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            guard let page = URL(string: release.htmlURL) else { return nil }
            return AppRelease(version: version, url: page)
        } catch {
            return nil
        }
    }
}
