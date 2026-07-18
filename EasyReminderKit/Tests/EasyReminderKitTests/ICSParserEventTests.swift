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
}
