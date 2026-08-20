import Foundation

/// 把 [ReminderItem] / [EventItem] 序列化成 ICS(VTODO / VEVENT) 文本。
public struct ICSExporter {

    public init() {}

    public func export(_ items: [ReminderItem]) -> String {
        wrap { lines in
            for item in items { lines.append(contentsOf: vtodo(item)) }
        }
    }

    public func export(events: [EventItem]) -> String {
        wrap { lines in
            for event in events { lines.append(contentsOf: vevent(event)) }
        }
    }

    /// 混合导出（待办 + 事件），供 CLI / 快捷指令用。
    public func export(content: ICSContent) -> String {
        wrap { lines in
            for item in content.todos { lines.append(contentsOf: vtodo(item)) }
            for event in content.events { lines.append(contentsOf: vevent(event)) }
        }
    }

    private func wrap(_ body: (inout [String]) -> Void) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//EasyReminder//Export//EN",
            "CALSCALE:GREGORIAN",
        ]
        body(&lines)
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private func vevent(_ item: EventItem) -> [String] {
        var l: [String] = ["BEGIN:VEVENT"]
        l.append("UID:\(item.uid ?? UUID().uuidString)")
        l.append("DTSTAMP:\(utc(Date()))")
        l.append("SUMMARY:\(escape(item.title))")
        if let notes = item.notes { l.append("DESCRIPTION:\(escape(notes))") }
        if let loc = item.location, !loc.isEmpty { l.append("LOCATION:\(escape(loc))") }
        if item.isAllDay {
            // 全天：VALUE=DATE；EventItem.endDate 已是 RFC 5545 的互斥日，直接写
            if let s = item.startDate { l.append("DTSTART;VALUE=DATE:\(dateOnly(s))") }
            if let e = item.endDate { l.append("DTEND;VALUE=DATE:\(dateOnly(e))") }
        } else {
            // 定时：统一 UTC 形式（Z），避免生成 TZID/VTIMEZONE
            if let s = item.startDate { l.append("DTSTART:\(utc(s))") }
            if let e = item.endDate { l.append("DTEND:\(utc(e))") }
        }
        if let url = item.url { l.append("URL:\(url.absoluteString)") }
        if let r = item.recurrence { l.append(rrule(r)) }
        for alarm in item.alarms { l.append(contentsOf: valarm(alarm)) }
        l.append("END:VEVENT")
        return l
    }

    private func vtodo(_ item: ReminderItem) -> [String] {
        var l: [String] = ["BEGIN:VTODO"]
        l.append("UID:\(item.uid ?? UUID().uuidString)")
        l.append("DTSTAMP:\(utc(Date()))")
        l.append("SUMMARY:\(escape(item.title))")
        if let notes = item.notes { l.append("DESCRIPTION:\(escape(notes))") }
        if let due = item.dueDate { l.append("DUE:\(utc(due))") }
        if let start = item.startDate { l.append("DTSTART:\(utc(start))") }
        if item.priority != 0 { l.append("PRIORITY:\(item.priority)") }
        l.append("STATUS:\(item.isCompleted ? "COMPLETED" : "NEEDS-ACTION")")
        l.append("PERCENT-COMPLETE:\(item.isCompleted ? 100 : 0)")
        if let url = item.url { l.append("URL:\(url.absoluteString)") }
        if let r = item.recurrence { l.append(rrule(r)) }
        for alarm in item.alarms { l.append(contentsOf: valarm(alarm)) }
        l.append("END:VTODO")
        return l
    }

    private func valarm(_ alarm: ReminderAlarm) -> [String] {
        switch alarm {
        case .relative(let offset):
            return ["BEGIN:VALARM", "ACTION:DISPLAY", "TRIGGER:\(duration(offset))", "END:VALARM"]
        case .absolute(let date):
            return ["BEGIN:VALARM", "ACTION:DISPLAY",
                    "TRIGGER;VALUE=DATE-TIME:\(utc(date))", "END:VALARM"]
        case .location(let loc):
            let prox = loc.onArrival ? "ARRIVE" : "DEPART"
            let geo = String(format: "geo:%.6f,%.6f", loc.latitude, loc.longitude)
            let structured = "X-APPLE-STRUCTURED-LOCATION;VALUE=URI;"
                + "X-APPLE-RADIUS=\(Int(loc.radius));X-TITLE=\"\(loc.title)\":\(geo)"
            return ["BEGIN:VALARM", "ACTION:DISPLAY",
                    "X-APPLE-PROXIMITY:\(prox)", "TRIGGER:-PT0S", structured, "END:VALARM"]
        }
    }

    private func rrule(_ r: RecurrenceRule) -> String {
        var s = "RRULE:FREQ=\(r.frequency.rawValue);INTERVAL=\(max(1, r.interval))"
        if !r.daysOfWeek.isEmpty {
            s += ";BYDAY=" + r.daysOfWeek.map(dayToken).joined(separator: ",")
        }
        if !r.daysOfMonth.isEmpty  { s += ";BYMONTHDAY=" + r.daysOfMonth.map(String.init).joined(separator: ",") }
        if !r.monthsOfYear.isEmpty { s += ";BYMONTH=" + r.monthsOfYear.map(String.init).joined(separator: ",") }
        if !r.setPositions.isEmpty { s += ";BYSETPOS=" + r.setPositions.map(String.init).joined(separator: ",") }
        if let c = r.count { s += ";COUNT=\(c)" }
        else if let u = r.until { s += ";UNTIL=\(utc(u))" }
        return s
    }

    private func dayToken(_ w: RecurrenceRule.Weekday) -> String {
        let codes = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"]
        let code = (1...7).contains(w.weekday) ? codes[w.weekday] : "MO"
        return w.weekNumber != 0 ? "\(w.weekNumber)\(code)" : code
    }

    // MARK: - 工具

    private func utc(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    // 全天日期（按设备时区取历法日）
    private func dateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    // 秒 → ISO8601 时长，负=提前
    private func duration(_ interval: TimeInterval) -> String {
        let neg = interval < 0
        var secs = Int(abs(interval))
        let days = secs / 86400; secs %= 86400
        let hours = secs / 3600; secs %= 3600
        let mins = secs / 60; secs %= 60
        var s = neg ? "-P" : "P"
        if days > 0 { s += "\(days)D" }
        s += "T"
        if hours > 0 { s += "\(hours)H" }
        if mins > 0 { s += "\(mins)M" }
        if secs > 0 || (hours == 0 && mins == 0) { s += "\(secs)S" }
        return s
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: ";", with: "\\;")
         .replacingOccurrences(of: ",", with: "\\,")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}
