import XCTest
import Foundation
import EasyReminderKit

/// 集成 / 冒烟测试：模拟 App 真实数据流 —— ReminderItem → 导出 ICS → 再解析 → 断言往返一致。
/// 这是对「解析器 + 导出器」整条链路最贴近实战的检查。
final class ICSRoundTripTests: XCTestCase {

    func testFullItemRoundTrip() {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 1; c.hour = 9; c.minute = 30; c.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let due = cal.date(from: c)!

        let original = ReminderItem(
            title: "买牛奶, 两升; 今天",            // 含逗号/分号，验证转义往返
            notes: "记得\n带袋子",                  // 含换行
            dueDate: due,
            priority: 5,
            isCompleted: false,
            url: URL(string: "https://example.com/x"),
            uid: "uid-round-trip-1",
            alarms: [.relative(-900)],
            recurrence: RecurrenceRule(frequency: .weekly, interval: 2, count: 5)
        )

        let text = ICSExporter().export([original])
        let parsed = ICSParser().parse(text)
        XCTAssertEqual(parsed.count, 1)
        let back = parsed[0]

        XCTAssertEqual(back.title, original.title)
        XCTAssertEqual(back.notes, original.notes)
        XCTAssertEqual(back.priority, 5)
        XCTAssertEqual(back.isCompleted, false)
        XCTAssertEqual(back.url, original.url)
        XCTAssertEqual(back.uid, "uid-round-trip-1")
        XCTAssertEqual(back.dueDate!.timeIntervalSince1970, due.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(back.recurrence?.frequency, .weekly)
        XCTAssertEqual(back.recurrence?.interval, 2)
        XCTAssertEqual(back.recurrence?.count, 5)
        XCTAssertEqual(back.alarms.count, 1)
        guard case .relative(let off) = back.alarms[0] else { return XCTFail("应为相对提醒") }
        XCTAssertEqual(off, -900, accuracy: 0.5)
    }

    func testLocationAlarmRoundTrip() {
        let loc = LocationTrigger(title: "公司", latitude: 40.0, longitude: -83.0, radius: 150, onArrival: true)
        let original = ReminderItem(title: "到公司提醒", alarms: [.location(loc)])

        let back = ICSParser().parse(ICSExporter().export([original]))[0]
        XCTAssertEqual(back.alarms.count, 1)
        guard case .location(let t) = back.alarms[0] else { return XCTFail("应为地点提醒") }
        XCTAssertEqual(t.title, "公司")
        XCTAssertEqual(t.latitude, 40.0, accuracy: 0.0001)
        XCTAssertEqual(t.longitude, -83.0, accuracy: 0.0001)
        XCTAssertEqual(t.radius, 150, accuracy: 0.5)
        XCTAssertTrue(t.onArrival)
    }

    /// BYDAY/BYMONTHDAY/BYMONTH/BYSETPOS 导出→再解析必须原样回来。
    func testByPartsRoundTrip() {
        let rule = RecurrenceRule(frequency: .monthly, interval: 2,
                                  count: 12,
                                  daysOfWeek: [.init(weekday: 3, weekNumber: 2), .init(weekday: 6, weekNumber: -1)],
                                  daysOfMonth: [15, -1],
                                  monthsOfYear: [3, 9],
                                  setPositions: [-1])
        let original = ReminderItem(title: "复杂重复", recurrence: rule)
        let back = ICSParser().parse(ICSExporter().export([original]))[0].recurrence
        XCTAssertEqual(back?.frequency, .monthly)
        XCTAssertEqual(back?.interval, 2)
        XCTAssertEqual(back?.count, 12)
        XCTAssertEqual(back?.daysOfWeek, rule.daysOfWeek)
        XCTAssertEqual(back?.daysOfMonth, rule.daysOfMonth)
        XCTAssertEqual(back?.monthsOfYear, rule.monthsOfYear)
        XCTAssertEqual(back?.setPositions, rule.setPositions)
    }

    func testMultipleItemsRoundTrip() {
        let items = [
            ReminderItem(title: "任务一", priority: 1),
            ReminderItem(title: "任务二", isCompleted: true),
            ReminderItem(title: "任务三", recurrence: RecurrenceRule(frequency: .monthly)),
        ]
        let back = ICSParser().parse(ICSExporter().export(items))
        XCTAssertEqual(back.map(\.title), ["任务一", "任务二", "任务三"])
        XCTAssertEqual(back[1].isCompleted, true)
        XCTAssertEqual(back[2].recurrence?.frequency, .monthly)
    }

    // MARK: - VEVENT 导出往返（日历 → ICS → 再解析）

    func testEventRoundTrip() {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 10; c.hour = 14; c.minute = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.date(from: c)!

        let original = EventItem(
            title: "组会; 每周",
            notes: "汇报进展\n带电脑",
            location: "Math Tower 100",
            startDate: start,
            endDate: start.addingTimeInterval(5400),
            isAllDay: false,
            url: URL(string: "https://example.com/meet"),
            uid: "ev-round-1",
            alarms: [.relative(-600)],
            recurrence: RecurrenceRule(frequency: .weekly, daysOfWeek: [.init(weekday: 5)])
        )

        let text = ICSExporter().export(events: [original])
        let back = ICSParser().parseContent(text).events
        XCTAssertEqual(back.count, 1)
        let e = back[0]
        XCTAssertEqual(e.title, original.title)
        XCTAssertEqual(e.notes, original.notes)
        XCTAssertEqual(e.location, original.location)
        XCTAssertEqual(e.uid, "ev-round-1")
        XCTAssertEqual(e.url, original.url)
        XCTAssertFalse(e.isAllDay)
        XCTAssertEqual(e.startDate!.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(e.endDate!.timeIntervalSince(e.startDate!), 5400, accuracy: 1)
        XCTAssertEqual(e.recurrence?.daysOfWeek, original.recurrence?.daysOfWeek)
        XCTAssertEqual(e.alarms.count, 1)
    }

    /// 全天事件：模型里 endDate 是互斥日，导出 DTEND;VALUE=DATE 后再解析要原样回来。
    func testAllDayEventRoundTrip() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))
        let endExclusive = cal.date(byAdding: .day, value: 3, to: start)!  // 三天的假期

        let original = EventItem(title: "假期", startDate: start, endDate: endExclusive, isAllDay: true)
        let back = ICSParser().parseContent(ICSExporter().export(events: [original])).events[0]
        XCTAssertTrue(back.isAllDay)
        XCTAssertEqual(back.startDate, start)
        XCTAssertEqual(back.endDate, endExclusive)
    }

    /// 带源时区的定时事件必须以 TZID 形式导出——固定 UTC 的重复系列跨夏令时会漂移一小时。
    func testEventTimeZoneRoundTrip() {
        let tz = TimeZone(identifier: "America/New_York")!
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 17; c.hour = 9
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let start = cal.date(from: c)!   // 纽约 09:00

        let original = EventItem(title: "周会", startDate: start,
                                 endDate: start.addingTimeInterval(3600), isAllDay: false,
                                 uid: "tz-round-1",
                                 recurrence: RecurrenceRule(frequency: .weekly),
                                 timeZone: tz)
        let text = ICSExporter().export(events: [original])
        XCTAssertTrue(text.contains("DTSTART;TZID=America/New_York:20260817T090000"),
                      "应导出本地时间 + TZID，而不是固定 UTC")
        let back = ICSParser().parseContent(text).events[0]
        XCTAssertEqual(back.startDate!.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(back.timeZone?.identifier, "America/New_York")
    }

    /// 混合导出：待办 + 事件写进同一份 ICS。
    func testMixedContentExport() {
        let content = ICSContent(todos: [ReminderItem(title: "待办甲")],
                                 events: [EventItem(title: "事件乙")])
        let back = ICSParser().parseContent(ICSExporter().export(content: content))
        XCTAssertEqual(back.todos.map(\.title), ["待办甲"])
        XCTAssertEqual(back.events.map(\.title), ["事件乙"])
    }
}

// MARK: - ImportLedger

final class ImportLedgerTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "EasyReminderKitTests.ledger")!
        defaults.removePersistentDomain(forName: "EasyReminderKitTests.ledger")
    }

    func testRecordAndRecall() {
        let ledger = ImportLedger(defaults: defaults)
        XCTAssertTrue(ledger.recordedUIDs().isEmpty)
        ledger.record(["a", "b"])
        ledger.record(["b", "c"])
        XCTAssertEqual(ledger.recordedUIDs(), ["a", "b", "c"])
    }

    func testEmptyRecordIsNoop() {
        let ledger = ImportLedger(defaults: defaults)
        ledger.record([])
        XCTAssertNil(defaults.stringArray(forKey: ImportLedger.defaultKey))
    }

    func testLocalizedErrorsHaveDescriptions() {
        XCTAssertNotNil(RemindersError.accessDenied.errorDescription)
        XCTAssertNotNil(RemindersError.noDefaultList.errorDescription)
        XCTAssertNotNil(CalendarError.accessDenied.errorDescription)
        XCTAssertNotNil(CalendarError.noDefaultCalendar.errorDescription)
        XCTAssertNotNil(CalendarError.calendarNotFound.errorDescription)
    }
}
