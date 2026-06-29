import Foundation

/// 把 ICS 文本解析成 [ReminderItem]。
/// 支持：RFC 5545 行展开、多个 VTODO、VALARM 子块、属性参数。
/// 字段：SUMMARY/DESCRIPTION/DUE/DTSTART/PRIORITY/STATUS/URL/UID/RRULE，
/// 以及 VALARM 的定时(TRIGGER)与地点(X-APPLE-PROXIMITY + 结构化地点)。
public struct ICSParser {

    private typealias Props = [String: (params: [String: String], value: String)]

    public init() {}

    /// 累计一条 VTODO 里 EventKit 写不进的私有字段（标签/子任务/附件）。
    private struct IgnoredCounter {
        var subtasks = 0
        var tags = 0
        var attachments = 0

        mutating func note(property name: String, value: String) {
            switch name {
            case "RELATED-TO": subtasks += 1
            case "ATTACH":     attachments += 1
            case "CATEGORIES": tags += value.split(separator: ",").count
            default: break
            }
        }

        func fields() -> [IgnoredField] {
            var result: [IgnoredField] = []
            if subtasks > 0    { result.append(.subtasks(subtasks)) }
            if tags > 0        { result.append(.tags(tags)) }
            if attachments > 0 { result.append(.attachments(attachments)) }
            return result
        }
    }

    public func parse(_ text: String) -> [ReminderItem] {
        let lines = unfold(text)
        var items: [ReminderItem] = []

        var todo: Props?
        var alarms: [Props] = []
        var alarm: Props?
        var ignored = IgnoredCounter()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            switch trimmed {
            case "BEGIN:VTODO":
                todo = [:]; alarms = []; alarm = nil; ignored = IgnoredCounter()
            case "BEGIN:VALARM":
                alarm = [:]
            case "END:VALARM":
                if let a = alarm { alarms.append(a) }
                alarm = nil
            case "END:VTODO":
                if let t = todo {
                    var item = makeItem(from: t, alarmBlocks: alarms)
                    item.ignoredFields = ignored.fields()
                    items.append(item)
                }
                todo = nil; alarms = []
            default:
                guard let (name, params, value) = parseProperty(line) else { continue }
                if alarm != nil {
                    alarm?[name] = (params, value)
                } else if todo != nil {
                    todo?[name] = (params, value)
                    ignored.note(property: name, value: value)
                }
            }
        }
        return items
    }

    // MARK: - 行展开

    private func unfold(_ text: String) -> [String] {
        let raw = text.replacingOccurrences(of: "\r\n", with: "\n")
                      .components(separatedBy: "\n")
        var result: [String] = []
        for line in raw {
            if let f = line.first, f == " " || f == "\t" {
                if !result.isEmpty { result[result.count - 1] += String(line.dropFirst()) }
            } else {
                result.append(line)
            }
        }
        return result
    }

    // MARK: - 拆一行： NAME;PARAM=VAL:VALUE

    private func parseProperty(_ line: String) -> (String, [String: String], String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let head = String(line[line.startIndex..<colon])
        let value = unescape(String(line[line.index(after: colon)...]))
        let parts = head.components(separatedBy: ";")
        let name = parts[0].uppercased()
        var params: [String: String] = [:]
        for p in parts.dropFirst() {
            let kv = p.components(separatedBy: "=")
            if kv.count == 2 { params[kv[0].uppercased()] = kv[1] }
        }
        return (name, params, value)
    }

    private func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\,", with: ",")
         .replacingOccurrences(of: "\\;", with: ";")
         .replacingOccurrences(of: "\\\\", with: "\\")
    }

    // MARK: - 组装 ReminderItem

    private func makeItem(from props: Props, alarmBlocks: [Props]) -> ReminderItem {
        let title = props["SUMMARY"]?.value ?? "(无标题)"
        let notes = props["DESCRIPTION"]?.value
        let url = props["URL"].flatMap { URL(string: $0.value) }
        let uid = props["UID"]?.value
        let priority = Int(props["PRIORITY"]?.value ?? "") ?? 0
        let isCompleted = (props["STATUS"]?.value.uppercased() == "COMPLETED")
        let dueDate = props["DUE"].flatMap { parseDate($0.value, params: $0.params) }
        let startDate = props["DTSTART"].flatMap { parseDate($0.value, params: $0.params) }
        let recurrence = props["RRULE"].flatMap { parseRecurrence($0.value) }
        let alarms = alarmBlocks.compactMap { parseAlarm($0) }

        return ReminderItem(title: title, notes: notes, dueDate: dueDate,
                            startDate: startDate, priority: priority,
                            isCompleted: isCompleted, url: url, uid: uid,
                            alarms: alarms, recurrence: recurrence)
    }

    // MARK: - 日期

    private func parseDate(_ value: String, params: [String: String]) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        if params["VALUE"] == "DATE" || value.count == 8 {
            fmt.dateFormat = "yyyyMMdd"; fmt.timeZone = .current
            return fmt.date(from: value)
        }
        if value.hasSuffix("Z") {
            fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"; fmt.timeZone = TimeZone(identifier: "UTC")
            return fmt.date(from: value)
        }
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"; fmt.timeZone = .current
        return fmt.date(from: value)
    }

    // MARK: - VALARM

    private func parseAlarm(_ p: Props) -> ReminderAlarm? {
        // 地点提醒优先
        if let prox = p["X-APPLE-PROXIMITY"]?.value.uppercased(),
           let loc = p["X-APPLE-STRUCTURED-LOCATION"],
           let trigger = parseLocation(loc.params, value: loc.value, arrival: prox == "ARRIVE") {
            return .location(trigger)
        }
        // 定时提醒
        guard let trig = p["TRIGGER"] else { return nil }
        if trig.params["VALUE"] == "DATE-TIME" {
            return parseDate(trig.value, params: trig.params).map { .absolute($0) }
        }
        return parseDuration(trig.value).map { .relative($0) }
    }

    private func parseLocation(_ params: [String: String], value: String, arrival: Bool) -> LocationTrigger? {
        let v = value.hasPrefix("geo:") ? String(value.dropFirst(4)) : value
        let parts = v.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
        let radius = Double(params["X-APPLE-RADIUS"] ?? "") ?? 100
        let title = (params["X-TITLE"] ?? "位置")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return LocationTrigger(title: title, latitude: lat, longitude: lon,
                               radius: radius, onArrival: arrival)
    }

    // ISO8601 时长： -PT15M / -P1DT2H / PT30M …（返回秒，负=提前）
    private func parseDuration(_ s: String) -> TimeInterval? {
        var str = s
        var sign = 1.0
        if str.hasPrefix("-") { sign = -1; str.removeFirst() }
        else if str.hasPrefix("+") { str.removeFirst() }
        guard str.hasPrefix("P") else { return nil }
        str.removeFirst()

        var total = 0.0
        var inTime = false
        var num = ""
        for ch in str {
            if ch == "T" { inTime = true; continue }
            if ch.isNumber { num.append(ch); continue }
            let v = Double(num) ?? 0; num = ""
            switch ch {
            case "W": total += v * 7 * 86400
            case "D": total += v * 86400
            case "H": total += v * 3600
            case "M": total += inTime ? v * 60 : v * 30 * 86400   // T 之前的 M 视为月（近似）
            case "S": total += v
            default: break
            }
        }
        return sign * total
    }

    // MARK: - RRULE

    private func parseRecurrence(_ value: String) -> RecurrenceRule? {
        var dict: [String: String] = [:]
        for part in value.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dict[kv[0].uppercased()] = String(kv[1]) }
        }
        guard let raw = dict["FREQ"],
              let freq = RecurrenceRule.Frequency(rawValue: raw.uppercased()) else { return nil }
        var rule = RecurrenceRule(frequency: freq)
        if let i = dict["INTERVAL"], let iv = Int(i) { rule.interval = max(1, iv) }
        if let c = dict["COUNT"], let cv = Int(c) { rule.count = cv }
        if let u = dict["UNTIL"] { rule.until = parseDate(u, params: [:]) }
        return rule
    }
}
