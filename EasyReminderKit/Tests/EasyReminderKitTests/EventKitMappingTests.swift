import XCTest
import EventKit
@testable import EasyReminderKit

/// EventKit 映射层的纯函数测试（不碰 EKEventStore，无需 TCC 权限）。
final class EventKitMappingTests: XCTestCase {

    /// 纽约时区日历（2026 春季调时 = 3 月 8 日 02:00）。
    private var nyCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func nyDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = h
        return nyCal.date(from: c)!
    }

    // MARK: - dateRange：全天

    func testSingleDayAllDay() {
        // ICS：DTSTART 3/7、DTEND 3/8（互斥）= 单日全天 → EK end = start
        let (s, e) = EventKitMapping.dateRange(start: nyDate(2026, 3, 7),
                                               end: nyDate(2026, 3, 8),
                                               isAllDay: true, calendar: nyCal)
        XCTAssertEqual(s, nyDate(2026, 3, 7))
        XCTAssertEqual(e, nyDate(2026, 3, 7))
    }

    /// 3/7–3/8 两天的全天事件（DTEND=3/9 互斥），末日恰跨春季调时：
    /// 固定 -86400 会把 end 算到 3/7 23:00、少一天；日历天运算必须落在 3/8。
    func testMultiDayAllDayAcrossSpringForward() {
        let (_, e) = EventKitMapping.dateRange(start: nyDate(2026, 3, 7),
                                               end: nyDate(2026, 3, 9),
                                               isAllDay: true, calendar: nyCal)
        XCTAssertEqual(nyCal.dateComponents([.year, .month, .day], from: e).day, 8)
    }

    func testMultiDayAllDayAcrossFallBack() {
        // 2026 秋季回拨 = 11 月 1 日。10/31–11/1（DTEND=11/2 互斥）→ EK end 落在 11/1
        let (_, e) = EventKitMapping.dateRange(start: nyDate(2026, 10, 31),
                                               end: nyDate(2026, 11, 2),
                                               isAllDay: true, calendar: nyCal)
        let comps = nyCal.dateComponents([.month, .day], from: e)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.day, 1)
    }

    /// 非零点的 end（固定秒数换算跨秋季回拨得到 23:00）要按天进位，不能丢最后一天。
    func testAllDayNonMidnightEndRoundsUp() {
        // 模拟旧换算产生的坏数据：end = 11/1 23:00（应视作 11/2 零点 = 互斥日）
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 1; c.hour = 23
        let badEnd = nyCal.date(from: c)!
        let (_, e) = EventKitMapping.dateRange(start: nyDate(2026, 10, 31), end: badEnd,
                                               isAllDay: true, calendar: nyCal)
        let comps = nyCal.dateComponents([.month, .day], from: e)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.day, 1)   // 两天的事件（10/31–11/1），EK end 落在 11/1
    }

    func testAllDayWithoutEnd() {
        let (s, e) = EventKitMapping.dateRange(start: nyDate(2026, 5, 1), end: nil,
                                               isAllDay: true, calendar: nyCal)
        XCTAssertEqual(s, e)
    }

    // MARK: - dateRange：定时

    func testTimedWithoutEndDefaultsToOneHour() {
        let start = nyDate(2026, 5, 1, 9)
        let (s, e) = EventKitMapping.dateRange(start: start, end: nil,
                                               isAllDay: false, calendar: nyCal)
        XCTAssertEqual(e.timeIntervalSince(s), 3600, accuracy: 1)
    }

    func testTimedEndBeforeStartClamped() {
        let start = nyDate(2026, 5, 1, 9)
        let (s, e) = EventKitMapping.dateRange(start: start, end: nyDate(2026, 5, 1, 8),
                                               isAllDay: false, calendar: nyCal)
        XCTAssertEqual(s, e)
    }

    func testNoStartFallsBackToNow() {
        let now = nyDate(2026, 5, 1, 12)
        let (s, _) = EventKitMapping.dateRange(start: nil, end: nil,
                                               isAllDay: false, calendar: nyCal, now: now)
        XCTAssertEqual(s, now)
    }

    // MARK: - RecurrenceRule → EKRecurrenceRule

    func testWeeklyByDayMapsAllDays() {
        let rule = RecurrenceRule(frequency: .weekly,
                                  daysOfWeek: [.init(weekday: 2), .init(weekday: 4), .init(weekday: 6)])
        let ek = EventKitMapping.recurrence(rule)
        XCTAssertEqual(ek.frequency, .weekly)
        XCTAssertEqual(ek.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue), [2, 4, 6])
        // weekly 规则的 weekNumber 必须为 0
        XCTAssertEqual(ek.daysOfTheWeek?.map(\.weekNumber), [0, 0, 0])
    }

    func testMonthlyOrdinalByDay() {
        let rule = RecurrenceRule(frequency: .monthly,
                                  daysOfWeek: [.init(weekday: 3, weekNumber: 2)])
        let ek = EventKitMapping.recurrence(rule)
        XCTAssertEqual(ek.daysOfTheWeek?.first?.weekNumber, 2)
    }

    func testByMonthDayAndSetPos() {
        let rule = RecurrenceRule(frequency: .monthly, daysOfMonth: [15, -1], setPositions: [-1])
        let ek = EventKitMapping.recurrence(rule)
        XCTAssertEqual(ek.daysOfTheMonth?.map(\.intValue), [15, -1])
        XCTAssertEqual(ek.setPositions?.map(\.intValue), [-1])
    }

    func testPlainRuleStillUsesSimpleForm() {
        let ek = EventKitMapping.recurrence(RecurrenceRule(frequency: .daily, interval: 3))
        XCTAssertEqual(ek.frequency, .daily)
        XCTAssertEqual(ek.interval, 3)
        XCTAssertNil(ek.daysOfTheWeek)
    }

    /// EK → 模型 → EK 往返（导出链路用）。
    func testRecurrenceModelRoundTrip() {
        let original = RecurrenceRule(frequency: .monthly, interval: 2, count: 6,
                                      daysOfWeek: [.init(weekday: 5, weekNumber: 1)],
                                      monthsOfYear: [4, 10])
        let back = EventKitMapping.recurrenceModel(EventKitMapping.recurrence(original))
        XCTAssertEqual(back.frequency, original.frequency)
        XCTAssertEqual(back.interval, original.interval)
        XCTAssertEqual(back.count, original.count)
        XCTAssertEqual(back.daysOfWeek, original.daysOfWeek)
        XCTAssertEqual(back.monthsOfYear, original.monthsOfYear)
    }

    // MARK: - Alarm 往返

    func testAlarmModelRoundTrip() {
        let rel = EventKitMapping.alarmModel(EventKitMapping.alarm(.relative(-900)))
        guard case .relative(let off) = rel else { return XCTFail("应为相对提醒") }
        XCTAssertEqual(off, -900, accuracy: 0.5)

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let abs = EventKitMapping.alarmModel(EventKitMapping.alarm(.absolute(date)))
        guard case .absolute(let d) = abs else { return XCTFail("应为绝对提醒") }
        XCTAssertEqual(d.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
    }
}
