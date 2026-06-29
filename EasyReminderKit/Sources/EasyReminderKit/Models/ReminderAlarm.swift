import Foundation

/// 一条提醒（VALARM）：定时（相对/绝对）或地点。
public enum ReminderAlarm {
    case relative(TimeInterval)   // 相对触发偏移，秒（负=提前）
    case absolute(Date)           // 绝对时间触发
    case location(LocationTrigger)
}

/// 地点触发（到达/离开某地点时提醒）。
public struct LocationTrigger {
    public var title: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double            // 触发半径，米
    public var onArrival: Bool           // true=到达触发，false=离开触发

    public init(title: String, latitude: Double, longitude: Double, radius: Double, onArrival: Bool) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.onArrival = onArrival
    }
}
