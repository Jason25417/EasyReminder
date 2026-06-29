import XCTest
import Foundation
import EasyReminderKit

/// 单元测试：ICSParser 各字段解析。
final class ICSParserTests: XCTestCase {
    private let parser = ICSParser()

    private func ics(_ lines: [String]) -> String { lines.joined(separator: "\n") }

    func testBasicFields() {
        let text = ics([
            "BEGIN:VCALENDAR", "BEGIN:VTODO",
            "UID:abc-123", "SUMMARY:买牛奶", "DESCRIPTION:两升",
            "PRIORITY:5", "STATUS:NEEDS-ACTION", "URL:https://example.com",
            "END:VTODO", "END:VCALENDAR",
        ])
        let items = parser.parse(text)
        XCTAssertEqual(items.count, 1)
        let item = items[0]
        XCTAssertEqual(item.title, "买牛奶")
        XCTAssertEqual(item.notes, "两升")
        XCTAssertEqual(item.priority, 5)
        XCTAssertFalse(item.isCompleted)
        XCTAssertEqual(item.uid, "abc-123")
        XCTAssertEqual(item.url, URL(string: "https://example.com"))
    }

    func testCompletedStatus() {
        let item = parser.parse(ics(["BEGIN:VTODO", "SUMMARY:x", "STATUS:COMPLETED", "END:VTODO"])).first
        XCTAssertEqual(item?.isCompleted, true)
    }

    func testMissingSummaryFallsBack() {
        let item = parser.parse(ics(["BEGIN:VTODO", "UID:1", "END:VTODO"])).first
        XCTAssertEqual(item?.title, "(无标题)")
    }

    func testMultipleTodos() {
        let text = ics(["BEGIN:VTODO", "SUMMARY:a", "END:VTODO",
                        "BEGIN:VTODO", "SUMMARY:b", "END:VTODO"])
        XCTAssertEqual(parser.parse(text).map(\.title), ["a", "b"])
    }

    func testRelativeAlarm() {
        let text = ics(["BEGIN:VTODO", "SUMMARY:x",
                        "BEGIN:VALARM", "ACTION:DISPLAY", "TRIGGER:-PT15M", "END:VALARM",
                        "END:VTODO"])
        let item = parser.parse(text).first!
        XCTAssertEqual(item.alarms.count, 1)
        guard case .relative(let offset) = item.alarms[0] else { return XCTFail("应为相对提醒") }
        XCTAssertEqual(offset, -900, accuracy: 0.5)
    }

    func testRecurrence() {
        let text = ics(["BEGIN:VTODO", "SUMMARY:x", "RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=5", "END:VTODO"])
        let rule = parser.parse(text).first!.recurrence
        XCTAssertEqual(rule?.frequency, .weekly)
        XCTAssertEqual(rule?.interval, 2)
        XCTAssertEqual(rule?.count, 5)
    }

    func testDueDateUTC() {
        let due = parser.parse(ics(["BEGIN:VTODO", "SUMMARY:x", "DUE:20260701T093000Z", "END:VTODO"])).first!.dueDate
        XCTAssertNotNil(due)
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 1; c.hour = 9; c.minute = 30; c.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(due!.timeIntervalSince1970, cal.date(from: c)!.timeIntervalSince1970, accuracy: 1)
    }

    func testLineUnfolding() {
        // 第二行以空格开头 = 折行续接，应拼回上一行
        let text = ics(["BEGIN:VTODO", "SUMMARY:很长的标", " 题继续", "END:VTODO"])
        XCTAssertEqual(parser.parse(text).first?.title, "很长的标题继续")
    }

    func testIgnoredFieldsDetected() {
        let text = ics([
            "BEGIN:VTODO", "SUMMARY:x",
            "CATEGORIES:work,urgent",        // 2 个标签
            "RELATED-TO:parent-uid",          // 1 个子任务
            "ATTACH:https://example.com/a.pdf",
            "ATTACH:https://example.com/b.pdf", // 2 个附件
            "END:VTODO",
        ])
        let item = parser.parse(text).first!
        XCTAssertEqual(Set(item.ignoredFields), [.tags(2), .subtasks(1), .attachments(2)])
    }

    func testNoIgnoredFields() {
        let item = parser.parse(ics(["BEGIN:VTODO", "SUMMARY:x", "END:VTODO"])).first!
        XCTAssertTrue(item.ignoredFields.isEmpty)
    }
}
