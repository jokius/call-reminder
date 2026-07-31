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

/// Запоминает, кого показали, и умеет притворяться занятым презентером.
@MainActor
private final class ShowSpy {
    var shown: [Meeting] = []
    var succeeds = true

    func show(_ meeting: Meeting) -> Bool {
        shown.append(meeting)
        return succeeds
    }
}

@Suite("Тик движка")
@MainActor
struct ReminderTickTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func meeting(id: String, startsIn seconds: TimeInterval, from base: Date) -> Meeting {
        Meeting(
            key: OccurrenceKey(seriesID: id, calendarID: "cal", occurrence: base.addingTimeInterval(seconds)),
            title: id,
            start: base.addingTimeInterval(seconds),
            end: base.addingTimeInterval(seconds + 1800),
            link: nil)
    }

    /// Свой домен UserDefaults на каждый тест: handled переживает запуски,
    /// и без изоляции второй прогон видел бы ключи первого.
    private func engine(_ name: String, events: [Meeting]) throws -> ReminderEngine {
        let suite = "callReminder.tests.\(name)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let engine = ReminderEngine(storage: HandledStore(defaults: defaults))
        engine.reload = { events }
        engine.refresh()
        return engine
    }

    @Test("презентер занят — встречу не теряем, предлагаем на следующем тике")
    func retriesWhenPresenterBusy() throws {
        let event = meeting(id: "a", startsIn: 30, from: epoch)
        let engine = try engine(#function, events: [event])
        let spy = ShowSpy()
        spy.succeeds = false
        engine.onShow = spy.show

        engine.tick(now: epoch)
        engine.tick(now: epoch.addingTimeInterval(1))

        #expect(spy.shown.map(\.title) == ["a", "a"])
    }

    @Test("показали — второй раз не предлагаем")
    func marksHandledAfterSuccessfulShow() throws {
        let event = meeting(id: "a", startsIn: 30, from: epoch)
        let engine = try engine(#function, events: [event])
        let spy = ShowSpy()
        engine.onShow = spy.show

        engine.tick(now: epoch)
        engine.tick(now: epoch.addingTimeInterval(1))

        #expect(spy.shown.map(\.title) == ["a"])
    }

    @Test("занятый презентер не съедает вторую встречу того же слота")
    func secondMeetingSurvivesBusyPresenter() throws {
        // два созвона в один и тот же момент: презентер показывает первый и на
        // второй отвечает false, потому что окно уже занято
        let first = meeting(id: "first", startsIn: 30, from: epoch)
        let second = meeting(id: "second", startsIn: 31, from: epoch)
        let engine = try engine(#function, events: [first, second])
        let spy = ShowSpy()
        engine.onShow = spy.show

        engine.tick(now: epoch)
        spy.succeeds = false
        engine.tick(now: epoch.addingTimeInterval(1))
        spy.succeeds = true
        engine.tick(now: epoch.addingTimeInterval(2))

        #expect(spy.shown.map(\.title) == ["first", "second", "second"])
    }
}
