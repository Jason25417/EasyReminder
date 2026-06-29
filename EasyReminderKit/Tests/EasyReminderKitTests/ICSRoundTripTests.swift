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
}
