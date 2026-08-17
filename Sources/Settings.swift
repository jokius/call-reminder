import AppKit
import Foundation
import ServiceManagement

enum BarFormat: String, CaseIterable, Sendable {
    case timeAndTitle
    case titleOnly
    case timeOnly

    var label: String {
        switch self {
        case .timeAndTitle: return String(localized: "Time and title")
        case .titleOnly: return String(localized: "Title only")
        case .timeOnly: return String(localized: "Time only")
        }
    }
}

/// Язык интерфейса. macOS умеет это и сама — System Settings → General →
/// Language & Region → Applications, — но про тот раздел почти никто не знает,
/// поэтому переключатель дублируется в настройках приложения.
enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case russian = "ru"

    /// Названия языков не переводятся: человек ищет знакомое слово на своём
    /// языке, даже когда интерфейс сейчас на чужом.
    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        leadMinutes = defaults.object(forKey: Keys.lead) as? Int ?? 1
        barFormat = BarFormat(rawValue: defaults.string(forKey: Keys.format) ?? "") ?? .timeAndTitle
        language =
            AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        // Отличаем «ещё ни разу не выбирал» от «снял все галочки сознательно».
        // Без этого пустой список приходилось трактовать как «все календари»,
        // и снятые галочки не выключали ничего.
        calendarsConfigured = defaults.object(forKey: Keys.calendars) != nil
        selectedCalendarIDs = Set(defaults.stringArray(forKey: Keys.calendars) ?? [])
    }

    private(set) var calendarsConfigured: Bool

    /// Варианты в выпадашке «показывать за».
    static let leadPresets = [1, 2, 3, 5, 10, 15, 30]

    private enum Keys {
        static let lead = "leadMinutes"
        static let format = "barFormat"
        static let calendars = "selectedCalendarIDs"
        /// Выбор пользователя. Отдельно от AppleLanguages намеренно: тот ключ
        /// перекрывается аргументами запуска (`-AppleLanguages (ru)`), и читать
        /// из него собственную настройку — значит иногда читать чужое значение.
        static let language = "uiLanguage"
        /// Системный ключ: его читает сам бандл на старте и выбирает .lproj.
        static let appleLanguages = "AppleLanguages"
    }

    /// Применяется при следующем запуске: локализацию бандл выбирает один раз,
    /// на старте. Поэтому смена языка в UI сопровождается перезапуском.
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            switch language {
            case .system:
                // Именно удаление, а не запись текущего системного кода: иначе
                // приложение навсегда застынет на языке, который был системным
                // в момент выбора, и перестанет следовать за настройками macOS.
                defaults.removeObject(forKey: Keys.appleLanguages)
            default:
                defaults.set([language.rawValue], forKey: Keys.appleLanguages)
            }
        }
    }

    var leadMinutes: Int {
        didSet { defaults.set(leadMinutes, forKey: Keys.lead) }
    }

    var barFormat: BarFormat {
        didSet { defaults.set(barFormat.rawValue, forKey: Keys.format) }
    }

    /// Идентификаторы календарей, а не названия: у пользователя бывает
    /// несколько разных календарей с одинаковым title.
    /// Пустое множество означает ровно то, что написано: ни одного.
    var selectedCalendarIDs: Set<String> {
        didSet {
            defaults.set(Array(selectedCalendarIDs), forKey: Keys.calendars)
            calendarsConfigured = true
        }
    }

    /// Первый запуск: включаем все календари, чтобы приложение сразу работало,
    /// но галочки при этом стоят — и снять их можно осмысленно.
    func selectAllIfUnconfigured(_ available: [CalendarInfo]) {
        guard !calendarsConfigured, !available.isEmpty else { return }
        selectedCalendarIDs = Set(available.map(\.id))
    }

    var lead: TimeInterval { TimeInterval(leadMinutes * 60) }
}

/// Перезапуск себя же: локализацию бандл выбирает на старте, поэтому новый
/// язык виден только в свежем процессе.
enum AppRestart {
    static func now() {
        let configuration = NSWorkspace.OpenConfiguration()
        // Без этого macOS просто активирует уже запущенный экземпляр, и вместо
        // перезапуска не произойдёт ничего.
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) {
            _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}

/// Автозапуск при входе. Для `.mainApp` отдельный helper-бандл не нужен.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Пользователь выключил автозапуск руками в System Settings.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            // Именно такой guard: при .notFound unregister() бросает ошибку.
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
