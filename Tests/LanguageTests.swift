import Foundation
import Testing

@testable import callReminder

@Suite("Выбор языка")
@MainActor
struct LanguageTests {

    private func suiteName(_ name: String) -> String { "test.callreminder.lang.\(name)" }

    private func freshDefaults(_ name: String) -> UserDefaults {
        let suite = suiteName(name)
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }

    /// Читаем именно записанное, а не эффективное значение: тестовая схема
    /// запускает хост с `-AppleLanguages (ru)`, а аргументы запуска перекрывают
    /// любой записанный ключ — обычный `stringArray(forKey:)` вернул бы «ru»
    /// независимо от того, что сохранило приложение.
    private func stored(_ key: String, in defaults: UserDefaults, suite: String) -> Any? {
        defaults.persistentDomain(forName: suite)?[key]
    }

    @Test("по умолчанию язык берётся у системы")
    func defaultsToSystem() {
        let settings = AppSettings(defaults: freshDefaults(#function))
        #expect(settings.language == .system)
    }

    @Test("выбор языка пишется в AppleLanguages — его читает сам бандл при запуске")
    func writesAppleLanguages() {
        let suite = suiteName(#function)
        let defaults = freshDefaults(#function)
        let settings = AppSettings(defaults: defaults)

        settings.language = .russian
        #expect(stored("AppleLanguages", in: defaults, suite: suite) as? [String] == ["ru"])

        settings.language = .english
        #expect(stored("AppleLanguages", in: defaults, suite: suite) as? [String] == ["en"])
    }

    @Test("возврат к системному снимает переопределение, а не пишет системный код")
    func systemRemovesOverride() {
        let suite = suiteName(#function)
        let defaults = freshDefaults(#function)
        let settings = AppSettings(defaults: defaults)

        settings.language = .russian
        settings.language = .system

        // Именно nil: иначе приложение навсегда прибьётся к языку, который был
        // системным в момент выбора, и перестанет следовать за настройками macOS.
        #expect(stored("AppleLanguages", in: defaults, suite: suite) == nil)
    }

    @Test("выбор переживает перезапуск")
    func survivesRestart() {
        let defaults = freshDefaults(#function)
        let settings = AppSettings(defaults: defaults)
        settings.language = .russian

        let restarted = AppSettings(defaults: defaults)
        #expect(restarted.language == .russian)
    }
}
