import Foundation

/// 读取 .ics 文本：处理 iCloud 未下载的占位文件与文件协调
/// （「文件」App / 共享表单给的是 file-provider 的就地 URL，直接裸读会失败或读到空）。
/// 安全作用域（security scope）由调用方负责。
public enum ICSFileReader {

    public enum ReadError: LocalizedError {
        case notDownloaded

        public var errorDescription: String? {
            switch self {
            case .notDownloaded:
                return String(localized: "文件还没从 iCloud 下载到本机，请稍后重试，或先在「文件」App 里打开一次",
                              bundle: .module)
            }
        }
    }

    /// 协调读取。iCloud 占位文件先触发下载并等待物化（最多 timeout 秒）。
    public static func readText(at url: URL, timeout: TimeInterval = 15) async throws -> String {
        try await materializeIfNeeded(at: url, timeout: timeout)

        var text = ""
        var coordError: NSError?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordError) { u in
            do { text = try String(contentsOf: u, encoding: .utf8) }
            catch { readError = error }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        return text
    }

    private static func materializeIfNeeded(at url: URL, timeout: TimeInterval) async throws {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
        guard let status = (try? url.resourceValues(forKeys: keys))?.ubiquitousItemDownloadingStatus,
              status != .current else { return }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? url.resourceValues(forKeys: keys))?.ubiquitousItemDownloadingStatus == .current {
                return
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        throw ReadError.notDownloaded
    }
}
