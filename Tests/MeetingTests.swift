import Foundation
import Testing

@testable import callReminder

@Suite("Граница суток")
struct EndOfDayTests {

    private func calendar(_ tz: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz) ?? .gmt
        return cal
    }

    private func date(_ iso: String, _ tz: String) throws -> Date {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(identifier: tz) ?? .gmt
        fmt.formatOptions = [.withInternetDateTime]
        return try #require(fmt.date(from: iso))
    }

    @Test("граница — ближайшая полночь, а не «сейчас плюс сутки»")
    func midnight() throws {
        let cal = calendar("Europe/Moscow")
        let evening = try date("2026-08-05T22:30:00+03:00", "Europe/Moscow")
        let expected = try date("2026-08-06T00:00:00+03:00", "Europe/Moscow")
        #expect(endOfDay(from: evening, calendar: cal) == expected)
    }

    @Test("вечером завтрашние встречи за границей остаются")
    func eveningDoesNotReachTomorrow() throws {
        let cal = calendar("Europe/Moscow")
        let evening = try date("2026-08-05T23:50:00+03:00", "Europe/Moscow")
        let tomorrowMorning = try date("2026-08-06T09:00:00+03:00", "Europe/Moscow")
        #expect(endOfDay(from: evening, calendar: cal) <= tomorrowMorning)
    }

    @Test("в день перехода на летнее время сутки не 24 часа")
    func daylightSaving() throws {
        // 29 марта 2026, Лондон: в 01:00 часы прыгают на 02:00, в сутках 23 часа.
        // Прибавление 86400 секунд промахнулось бы мимо полуночи на час.
        let cal = calendar("Europe/London")
        let noon = try date("2026-03-29T12:00:00+01:00", "Europe/London")
        let midnight = endOfDay(from: noon, calendar: cal)
        let components = cal.dateComponents([.hour, .minute], from: midnight)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }
}

@Suite("Правила отбора событий")
struct EventFilterTests {

    private func candidate(
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        participation: MyParticipation = .notInvited
    ) -> EventCandidate {
        EventCandidate(isAllDay: isAllDay, isCancelled: isCancelled, participation: participation)
    }

    @Test("обычная встреча проходит")
    func normal() {
        #expect(shouldRemind(candidate()))
    }

    @Test("событие на весь день не напоминаем")
    func allDay() {
        #expect(!shouldRemind(candidate(isAllDay: true)))
    }

    @Test("отменённую встречу не напоминаем")
    func cancelled() {
        #expect(!shouldRemind(candidate(isCancelled: true)))
    }

    @Test("отклонённое приглашение не напоминаем")
    func declined() {
        #expect(!shouldRemind(candidate(participation: .declined)))
    }

    @Test("личное событие без участников напоминаем")
    func ownEventWithoutAttendees() {
        // Замер на живом календаре: событие «Регистрация» в собственном календаре,
        // без участников и помеченное «свободен», отсеивалось прежним правилом
        // по availability — хотя напомнить о нём как раз и надо.
        #expect(shouldRemind(candidate(participation: .notInvited)))
    }

    @Test("приглашение без ответа напоминаем")
    func pendingInvite() {
        #expect(shouldRemind(candidate(participation: .pending)))
    }
}
