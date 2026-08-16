import Foundation
import Testing

@testable import callReminder

/// Ключа нет в каталоге — `String(localized:)` молча возвращает сам ключ, и кнопка
/// остаётся английской в русской сборке. Строки из MenuBarLabel защищены тестами
/// формата, а UI-строки не покрывал никто: ровно так и уехал «Skip» вместо
/// «Пропустить». Схема гоняет тесты с -AppleLanguages (ru), поэтому равенство
/// перевода ключу означает именно дырку в каталоге.
@Suite("Полнота локализации")
struct LocalizationTests {
    @Test(
        "каждая строка интерфейса переведена на русский",
        arguments: [
            "Join", "Skip", "Dismiss", "No meeting link",
            "No access", "No Calendar access — open Settings", "No meetings today",
            "Settings…", "Quit", "Privacy Policy",
            "Reminder", "Notify before", "Menu bar", "Show", "Calendars",
            "No calendars available", "Only checked calendars are used.",
            "Launch at login", "Allow in System Settings",
            "Time and title", "Title only", "Time only",
            "Untitled", "Call",
        ])
    func translated(key: String) {
        let localized = String(localized: String.LocalizationValue(key))
        #expect(
            localized != key,
            "ключа «\(key)» нет в Localizable.xcstrings — строка осталась английской")
    }
}
