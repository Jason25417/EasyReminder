import XCTest
import Foundation
import EasyReminderKit

/// 单元测试：ICSExporter 输出结构与转义。
final class ICSExporterTests: XCTestCase {
    private let exporter = ICSExporter()

    func testHeaderAndStructure() {
        let text = exporter.export([ReminderItem(title: "x")])
        for needle in ["BEGIN:VCALENDAR", "VERSION:2.0", "BEGIN:VTODO", "SUMMARY:x", "END:VTODO", "END:VCALENDAR"] {
            XCTAssertTrue(text.contains(needle), "缺少 \(needle)")
        }
        XCTAssertTrue(text.hasSuffix("\r\n"))
    }

    func testPriorityOmittedWhenZero() {
        XCTAssertFalse(exporter.export([ReminderItem(title: "x", priority: 0)]).contains("PRIORITY:"))
    }

    func testCompletedStatus() {
        let text = exporter.export([ReminderItem(title: "x", isCompleted: true)])
        XCTAssertTrue(text.contains("STATUS:COMPLETED"))
        XCTAssertTrue(text.contains("PERCENT-COMPLETE:100"))
    }

    func testEscaping() {
        // 逗号/分号需转义为 \, \;
        XCTAssertTrue(exporter.export([ReminderItem(title: "a,b;c")]).contains("SUMMARY:a\\,b\\;c"))
    }

    func testRecurrenceExport() {
        let text = exporter.export([ReminderItem(title: "x", recurrence: RecurrenceRule(frequency: .daily, interval: 3))])
        XCTAssertTrue(text.contains("RRULE:FREQ=DAILY;INTERVAL=3"))
    }
}
