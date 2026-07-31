import Foundation
import Testing

@testable import callReminder

@Suite("Решение о показе напоминания")
struct ReminderDecisionTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func meeting(id: String, startsIn seconds: TimeInterval, from base: Date) -> Meeting {
        Meeting(
            key: OccurrenceKey(seriesID: id, calendarID: "cal", occurrence: base.addingTimeInterval(seconds)),
            title: id,
            start: base.addingTimeInterval(seconds),
            end: base.addingTimeInterval(seconds + 1800),
            link: nil)
    }

    @Test("до окна напоминания молчим")
    func beforeWindow() {
        let event = meeting(id: "a", startsIn: 600, from: epoch)
        #expect(meetingToShow(events: [event], now: epoch, lead: 60, handled: []) == nil)
    }

    @Test("ровно на границе окна показываем")
    func exactlyAtWindowEdge() {
        let event = meeting(id: "a", startsIn: 60, from: epoch)
        #expect(meetingToShow(events: [event], now: epoch, lead: 60, handled: [])?.title == "a")
    }

    @Test("внутри окна показываем")
    func insideWindow() {
        let event = meeting(id: "a", startsIn: 30, from: epoch)
        #expect(meetingToShow(events: [event], now: epoch, lead: 60, handled: [])?.title == "a")
    }

    @Test("уже начавшуюся встречу не догоняем")
    func alreadyStarted() {
        let event = meeting(id: "a", startsIn: -1, from: epoch)
        #expect(meetingToShow(events: [event], now: epoch, lead: 60, handled: []) == nil)
    }

    @Test("обработанную встречу второй раз не показываем")
    func handledOnce() {
        let event = meeting(id: "a", startsIn: 30, from: epoch)
        #expect(meetingToShow(events: [event], now: epoch, lead: 60, handled: [event.key]) == nil)
    }

    @Test("из двух подходящих берём ту, что начинается раньше")
    func earliestWins() {
        let late = meeting(id: "late", startsIn: 50, from: epoch)
        let soon = meeting(id: "soon", startsIn: 20, from: epoch)
        #expect(meetingToShow(events: [late, soon], now: epoch, lead: 60, handled: [])?.title == "soon")
    }

    @Test("после сна: окно проспали, встреча ещё не началась — показываем")
    func wokeUpInsideWindow() {
        // ноутбук спал с epoch до epoch+55, тик пропущен, но условие всё ещё выполняется
        let event = meeting(id: "a", startsIn: 60, from: epoch)
        let afterSleep = epoch.addingTimeInterval(55)
        #expect(meetingToShow(events: [event], now: afterSleep, lead: 60, handled: [])?.title == "a")
    }
}
