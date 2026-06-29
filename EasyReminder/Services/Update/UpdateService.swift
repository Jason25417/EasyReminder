import Foundation

/// 一个可下载的发布版本。
struct AppRelease {
    let version: String   // 已去掉前导 "v"，如 "1.1.0"
    let url: URL          // 对应的 GitHub Release 页面
}

protocol UpdateService {
    /// 取最新 Release；无 Release / 网络失败一律返回 nil（更新检查不该打扰用户）。
    func latestRelease() async -> AppRelease?
}

/// 比较版本号（如 "1.0" vs "1.1.2"）：lhs 比 rhs 旧则返回 true。按点分段做数值比较。
func isVersion(_ lhs: String, olderThan rhs: String) -> Bool {
    func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
    let a = parts(lhs), b = parts(rhs)
    for i in 0..<max(a.count, b.count) {
        let x = i < a.count ? a[i] : 0
        let y = i < b.count ? b[i] : 0
        if x != y { return x < y }
    }
    return false
}
