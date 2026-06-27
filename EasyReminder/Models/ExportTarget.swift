import Foundation

/// 导出目标：真实列表，或我们用条件重建的智能筛选。
struct ExportTarget: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: Kind

    enum Kind: Hashable {
        case list(calendarID: String)   // 真实列表
        case all                        // 全部（所有列表）
        case today                      // 今天到期且未完成
        case scheduled                  // 有到期日且未完成
        case completed                  // 已完成
    }
}
