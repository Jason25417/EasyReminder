import XCTest
@testable import EasyReminderKit

final class ICSParserEventTests: XCTestCase {

    private func wrap(_ body: String) -> String {
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n\(body)\r\nEND:VCALENDAR\r\n"
    }

    func testParsesBasicEvent() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        UID:ev-1\r
        SUMMARY:期末考试\r
        DESCRIPTION:带计算器\r
        LOCATION:Journalism Bldg 300\r
        DTSTART:20260801T090000Z\r
        DTEND:20260801T110000Z\r
        URL:https://example.com\r
        END:VEVENT
        """)
        let content = ICSParser().parseContent(ics)
        XCTAssertEqual(content.events.count, 1)
        XCTAssertTrue(content.todos.isEmpty)
        let e = content.events[0]
        XCTAssertEqual(e.title, "期末考试")
        XCTAssertEqual(e.notes, "带计算器")
        XCTAssertEqual(e.location, "Journalism Bldg 300")
        XCTAssertEqual(e.uid, "ev-1")
        XCTAssertEqual(e.url?.absoluteString, "https://example.com")
        XCTAssertFalse(e.isAllDay)
        XCTAssertNotNil(e.startDate)
        XCTAssertEqual(e.endDate!.timeIntervalSince(e.startDate!), 7200, accuracy: 1)
    }

    func testAllDayEvent() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:假期\r
        DTSTART;VALUE=DATE:20260810\r
        DTEND;VALUE=DATE:20260811\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertTrue(e.isAllDay)
        XCTAssertNotNil(e.startDate)
        XCTAssertNotNil(e.endDate)
    }

    func testDurationAsEnd() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:会议\r
        DTSTART:20260801T090000Z\r
        DURATION:PT45M\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertEqual(e.endDate!.timeIntervalSince(e.startDate!), 45 * 60, accuracy: 1)
    }

    func testMixedTodoAndEvent() {
        let ics = wrap("""
        BEGIN:VTODO\r
        SUMMARY:交作业\r
        DUE:20260801T235900Z\r
        END:VTODO\r
        BEGIN:VEVENT\r
        SUMMARY:上课\r
        DTSTART:20260801T130000Z\r
        END:VEVENT
        """)
        let content = ICSParser().parseContent(ics)
        XCTAssertEqual(content.todos.count, 1)
        XCTAssertEqual(content.events.count, 1)
        XCTAssertEqual(content.todos[0].title, "交作业")
        XCTAssertEqual(content.events[0].title, "上课")
        // 旧接口仍只回 VTODO
        XCTAssertEqual(ICSParser().parse(ics).count, 1)
    }

    func testEventAlarmAndRecurrence() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:周会\r
        DTSTART:20260803T020000Z\r
        RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=10\r
        BEGIN:VALARM\r
        TRIGGER:-PT15M\r
        ACTION:DISPLAY\r
        END:VALARM\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertEqual(e.recurrence?.frequency, .weekly)
        XCTAssertEqual(e.recurrence?.count, 10)
        XCTAssertEqual(e.alarms.count, 1)
        if case .relative(let off) = e.alarms[0] {
            XCTAssertEqual(off, -900, accuracy: 1)
        } else {
            XCTFail("应为相对提醒")
        }
    }

    func testEventWithoutEndOrDuration() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:未定结束\r
        DTSTART:20260801T090000Z\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertNil(e.endDate)
        XCTAssertNotNil(e.startDate)
    }

    // MARK: - TZID

    /// TZID 必须按其所指时区解释（Google/Outlook/Zoom 导出的默认写法），
    /// 而不是设备本地时区。LA 九月为 PDT(UTC-7)：09:00 → 16:00Z。
    func testTZIDIsHonored() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:跨时区会议\r
        DTSTART;TZID=America/Los_Angeles:20260901T090000\r
        DTEND;TZID=America/Los_Angeles:20260901T100000\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        let expected = utcDate(2026, 9, 1, 16, 0)
        XCTAssertEqual(e.startDate!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(e.endDate!.timeIntervalSince(e.startDate!), 3600, accuracy: 1)
        XCTAssertEqual(e.timeZone?.identifier, "America/Los_Angeles")
    }

    /// RFC 5545 允许参数值带双引号：TZID="Europe/London" 也要能识别。
    func testQuotedTZID() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:伦敦会议\r
        DTSTART;TZID="Europe/London":20260901T120000\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        // 伦敦九月为 BST(UTC+1)：12:00 → 11:00Z
        let expected = utcDate(2026, 9, 1, 11, 0)
        XCTAssertEqual(e.startDate!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(e.timeZone?.identifier, "Europe/London")
    }

    /// 识别不了的 TZID（Outlook 的 Windows 时区名）回落设备时区，不崩、不丢事件。
    func testUnknownTZIDFallsBackToDeviceZone() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:Windows 时区\r
        DTSTART;TZID=Pacific Standard Time:20260901T090000\r
        END:VEVENT
        """)
        let content = ICSParser().parseContent(ics)
        XCTAssertEqual(content.events.count, 1)
        let e = content.events[0]
        XCTAssertNotNil(e.startDate)
        XCTAssertNil(e.timeZone)
        // 回落行为 = 按设备时区解释
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        fmt.timeZone = .current
        XCTAssertEqual(e.startDate, fmt.date(from: "20260901T090000"))
    }

    /// VTODO 的 DUE 同样要吃 TZID。
    func testTodoDueWithTZID() {
        let ics = wrap("""
        BEGIN:VTODO\r
        SUMMARY:交报告\r
        DUE;TZID=Asia/Shanghai:20260901T180000\r
        END:VTODO
        """)
        let t = ICSParser().parseContent(ics).todos[0]
        // 上海 UTC+8：18:00 → 10:00Z
        let expected = utcDate(2026, 9, 1, 10, 0)
        XCTAssertEqual(t.dueDate!.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    private func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    // MARK: - RRULE BY*

    /// 一周三节课（BYDAY=MO,WE,FR）不能被降级成「每周一次」。
    func testRRuleByDayWeekly() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:课程\r
        DTSTART:20260824T130000Z\r
        RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=20261211T000000Z\r
        END:VEVENT
        """)
        let r = ICSParser().parseContent(ics).events[0].recurrence
        XCTAssertEqual(r?.frequency, .weekly)
        XCTAssertEqual(r?.daysOfWeek, [.init(weekday: 2), .init(weekday: 4), .init(weekday: 6)])
        XCTAssertNotNil(r?.until)
    }

    /// 每月第 2 个周二（BYDAY=2TU）与倒数第一个周五（-1FR）。
    func testRRuleByDayOrdinal() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:例会\r
        DTSTART:20260901T130000Z\r
        RRULE:FREQ=MONTHLY;BYDAY=2TU,-1FR\r
        END:VEVENT
        """)
        let r = ICSParser().parseContent(ics).events[0].recurrence
        XCTAssertEqual(r?.daysOfWeek, [.init(weekday: 3, weekNumber: 2), .init(weekday: 6, weekNumber: -1)])
    }

    func testRRuleByMonthDayMonthSetPos() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:发薪\r
        DTSTART:20260131T090000Z\r
        RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;BYMONTH=1,7;BYSETPOS=1\r
        END:VEVENT
        """)
        let r = ICSParser().parseContent(ics).events[0].recurrence
        XCTAssertEqual(r?.daysOfMonth, [-1])
        XCTAssertEqual(r?.monthsOfYear, [1, 7])
        XCTAssertEqual(r?.setPositions, [1])
    }

    /// COUNT=0 会让 EKRecurrenceEnd(occurrenceCount:) 抛 ObjC 异常，必须钳位到 ≥1。
    func testRRuleCountZeroClamped() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:坏数据\r
        DTSTART:20260901T090000Z\r
        RRULE:FREQ=DAILY;COUNT=0\r
        END:VEVENT
        """)
        let r = ICSParser().parseContent(ics).events[0].recurrence
        XCTAssertEqual(r?.count, 1)
    }

    // MARK: - 跳过与忽略（诚实兜底）

    /// Google 导出形状：主重复块 + 移动过的覆盖块 + 已取消的覆盖块（同一 UID）。
    /// 只导主块；两个覆盖块分别计入 skippedOverrides，不产生重复/幽灵事件。
    func testRecurrenceOverridesAreSkippedNotDuplicated() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        UID:series-1\r
        SUMMARY:周会\r
        DTSTART:20260901T130000Z\r
        RRULE:FREQ=WEEKLY;BYDAY=TU\r
        END:VEVENT\r
        BEGIN:VEVENT\r
        UID:series-1\r
        RECURRENCE-ID:20260908T130000Z\r
        SUMMARY:周会（移到周三）\r
        DTSTART:20260909T130000Z\r
        END:VEVENT\r
        BEGIN:VEVENT\r
        UID:series-1\r
        RECURRENCE-ID:20260915T130000Z\r
        STATUS:CANCELLED\r
        SUMMARY:周会\r
        DTSTART:20260915T130000Z\r
        END:VEVENT
        """)
        let content = ICSParser().parseContent(ics)
        XCTAssertEqual(content.events.count, 1)
        XCTAssertEqual(content.events[0].title, "周会")
        XCTAssertEqual(content.skippedOverrides, 2)
    }

    /// 独立的 STATUS:CANCELLED 事件（无 RECURRENCE-ID）同样跳过。
    func testStandaloneCancelledEventSkipped() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:被取消的活动\r
        STATUS:CANCELLED\r
        DTSTART:20260901T130000Z\r
        END:VEVENT
        """)
        let content = ICSParser().parseContent(ics)
        XCTAssertTrue(content.events.isEmpty)
        XCTAssertEqual(content.skippedCancelled, 1)
    }

    /// ATTENDEE/ORGANIZER/EXDATE 写不进日历，必须进 ignoredFields 提示。
    func testEventIgnoredFieldsCollected() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:项目会\r
        DTSTART:20260901T130000Z\r
        RRULE:FREQ=WEEKLY\r
        ORGANIZER:mailto:boss@example.com\r
        ATTENDEE:mailto:a@example.com\r
        ATTENDEE:mailto:b@example.com\r
        EXDATE:20260908T130000Z,20260915T130000Z\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertTrue(e.ignoredFields.contains(.attendees(3)))
        XCTAssertTrue(e.ignoredFields.contains(.exceptionDates(2)))
    }

    /// 认不出的 TZID 要在 ignoredFields 里挂号，而不是无声回落。
    func testUnknownTZIDNotedAsIgnored() {
        let ics = wrap("""
        BEGIN:VEVENT\r
        SUMMARY:Outlook 事件\r
        DTSTART;TZID=Pacific Standard Time:20260901T090000\r
        END:VEVENT
        """)
        let e = ICSParser().parseContent(ics).events[0]
        XCTAssertTrue(e.ignoredFields.contains(.unresolvedTimeZone("Pacific Standard Time")))
    }

    /// VTODO 的忽略字段行为回归：RELATED-TO/CATEGORIES/ATTACH 照旧计数。
    func testTodoIgnoredFieldsRegression() {
        let ics = wrap("""
        BEGIN:VTODO\r
        SUMMARY:大任务\r
        RELATED-TO:sub-1\r
        CATEGORIES:学习,工作\r
        ATTACH:https://example.com/f.pdf\r
        END:VTODO
        """)
        let t = ICSParser().parseContent(ics).todos[0]
        XCTAssertTrue(t.ignoredFields.contains(.subtasks(1)))
        XCTAssertTrue(t.ignoredFields.contains(.tags(2)))
        XCTAssertTrue(t.ignoredFields.contains(.attachments(1)))
    }
}
