import Foundation

/// 一条提醒（VALARM）：定时（相对/绝对）或地点。
enum ReminderAlarm {
    case relative(TimeInterval)   // 相对触发偏移，秒（负=提前）
    case absolute(Date)           // 绝对时间触发
    case location(LocationTrigger)
}

/// 地点触发（到达/离开某地点时提醒）。
struct LocationTrigger {
    var title: String
    var latitude: Double
    var longitude: Double
    var radius: Double            // 触发半径，米
    var onArrival: Bool           // true=到达触发，false=离开触发
}
