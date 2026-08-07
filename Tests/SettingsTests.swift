import Foundation
import Testing

@testable import callReminder

@Suite("Выбор календарей")
@MainActor
struct CalendarSelectionTests {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let suite = "test.callreminder.\(name)"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }

    private let calendars = [
        CalendarInfo(id: "a", title: "Работа", account: "Exchange"),
        CalendarInfo(id: "b", title: "Личное", account: "iCloud"),
    ]

    @Test("первый запуск — все календари включаются сами")
    func firstLaunchSelectsAll() {
        let settings = AppSettings(defaults: freshDefaults(#function))
        #expect(!settings.calendarsConfigured)

        settings.selectAllIfUnconfigured(calendars)
        #expect(settings.selectedCalendarIDs == ["a", "b"])
        #expect(settings.calendarsConfigured)
    }

    @Test("снятые галочки остаются снятыми и не переоткрываются при следующем запуске")
    func emptySelectionIsRespected() {
        let defaults = freshDefaults(#function)
        let settings = AppSettings(defaults: defaults)
        settings.selectAllIfUnconfigured(calendars)

        // пользователь снял все галочки
        settings.selectedCalendarIDs = []

        // следующий запуск читает те же UserDefaults
        let restarted = AppSettings(defaults: defaults)
        #expect(restarted.calendarsConfigured)
        restarted.selectAllIfUnconfigured(calendars)
        #expect(restarted.selectedCalendarIDs.isEmpty, "пустой выбор — это «ни одного», а не «все»")
    }

    @Test("выбор одного календаря переживает перезапуск")
    func partialSelectionSurvives() {
        let defaults = freshDefaults(#function)
        let settings = AppSettings(defaults: defaults)
        settings.selectedCalendarIDs = ["b"]

        let restarted = AppSettings(defaults: defaults)
        restarted.selectAllIfUnconfigured(calendars)
        #expect(restarted.selectedCalendarIDs == ["b"])
    }
}
