import Foundation
import ServiceManagement

enum BarFormat: String, CaseIterable, Sendable {
    case timeAndTitle
    case titleOnly

    var label: String {
        switch self {
        case .timeAndTitle: return "Время и название"
        case .titleOnly: return "Только название"
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
        selectedCalendarIDs = Set(defaults.stringArray(forKey: Keys.calendars) ?? [])
    }

    private enum Keys {
        static let lead = "leadMinutes"
        static let format = "barFormat"
        static let calendars = "selectedCalendarIDs"
    }

    var leadMinutes: Int {
        didSet { defaults.set(leadMinutes, forKey: Keys.lead) }
    }

    var barFormat: BarFormat {
        didSet { defaults.set(barFormat.rawValue, forKey: Keys.format) }
    }

    /// Идентификаторы календарей, а не названия: у пользователя бывает
    /// несколько разных календарей с одинаковым title. Пустое множество = все.
    var selectedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(selectedCalendarIDs), forKey: Keys.calendars) }
    }

    var lead: TimeInterval { TimeInterval(leadMinutes * 60) }
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
