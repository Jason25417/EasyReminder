import Foundation

/// 把 [ReminderItem] 序列化成 ICS(VTODO) 文本。
struct ICSExporter {

    func export(_ items: [ReminderItem]) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//MyApp//Export//EN",
            "CALSCALE:GREGORIAN",
        ]
        for item in items { lines.append(contentsOf: vtodo(item)) }
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n") + "\r\n"
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
        if let c = r.count { s += ";COUNT=\(c)" }
        else if let u = r.until { s += ";UNTIL=\(utc(u))" }
        return s
    }

    // MARK: - 工具

    private func utc(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
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
