import Foundation

/// 已导入 ICS UID 的本地账本（查重用）。
/// App（GUI）与快捷指令同进程、共用同一份记录，避免自动化重复导入污染数据。
/// CLI 是独立进程（UserDefaults 域与沙盒 App 不通），**不做查重**——重复运行同一文件会重复建条目。
/// 仅本机（UserDefaults），刻意不跨设备。
public struct ImportLedger {
    public static let defaultKey = "EasyReminder.importedUIDs"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = ImportLedger.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func recordedUIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    public func record(_ uids: [String]) {
        guard !uids.isEmpty else { return }
        var s = recordedUIDs()
        s.formUnion(uids)
        defaults.set(Array(s), forKey: key)
    }
}
