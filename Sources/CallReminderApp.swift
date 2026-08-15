import AppKit
import EventKit
import SwiftUI

/// Сколько минут осталось до `date`, округляя вниз.
enum Countdown {
    static func minutesUntil(_ date: Date, from now: Date) -> Int {
        Int((date.timeIntervalSince(now) / 60).rounded(.down))
    }
}

@main
struct CallReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            // Image + Text — единственное, что MenuBarExtra реально кладёт
            // в статус-айтем: стили и фигуры он молча выбрасывает.
            Image("TrayIcon")
            // label у MenuBarExtra рендерится не как SwiftUI-вьюха: текст ложится
            // в title статус-айтема, всё остальное молча выбрасывается. Поэтому
            // здесь только Text — стили и фигуры не имеют смысла.
            Text(delegate.model.barText)
        }

        Settings {
            SettingsView(settings: delegate.model.settings, calendars: delegate.model.calendars)
        }
    }
}

/// Состояние приложения. Живёт в делегате, а не в сцене: content у MenuBarExtra
/// и у Settings инстанцируются лениво, и до первого открытия меню их просто нет.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    private(set) var calendars: [CalendarInfo] = []
    private(set) var accessDenied = false

    private let calendar = CalendarService()
    private let engine = ReminderEngine()
    private let presenter = AlertPresenter()

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    var barText: String {
        accessDenied
            ? String(localized: "No access")
            : menuBarText(next: engine.next, now: engine.now, format: settings.barFormat)
    }

    var upcoming: [Meeting] { Array(engine.events.prefix(8)) }

    func start() async {
        do {
            guard try await calendar.requestAccess() else {
                accessDenied = true
                return
            }
        } catch {
            accessDenied = true
            return
        }

        calendars = calendar.calendars()
        // Первый запуск: галочки проставляются сами, дальше выбор за пользователем.
        settings.selectAllIfUnconfigured(calendars)
        calendar.onChange = { [weak self] in
            self?.reloadCalendars()
            self?.engine.refresh()
        }
        calendar.startObserving()

        // reload и onShow — строго до start(): refresh() при reload == nil молча
        // выходит, и движок тикал бы по пустому списку.
        engine.reload = { [weak self] in
            guard let self else { return [] }
            return self.calendar.upcoming(calendarIDs: self.settings.selectedCalendarIDs)
        }
        engine.lead = settings.lead
        engine.onShow = { [weak self] meeting in
            self?.present(meeting) ?? false
        }
        engine.start()
    }

    /// Настройки могли поменяться, пока меню было закрыто.
    func syncSettings() {
        engine.lead = settings.lead
        engine.refresh()
    }

    private func reloadCalendars() {
        calendars = calendar.calendars()
    }

    /// Возвращает false, если презентер занят: тогда движок оставит встречу в очереди.
    private func present(_ meeting: Meeting) -> Bool {
        presenter.show(meeting) { [weak self] in
            self?.presenter.dismiss()
            guard let link = meeting.link else { return }
            Task { await MeetingLink.open(link) }
        } onSkip: { [weak self] in
            self?.presenter.dismiss()
        }
    }

    func openSystemCalendarSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = model
        Task { await model.start() }
    }
}

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if model.accessDenied {
            Button("No Calendar access — open Settings") {
                model.openSystemCalendarSettings()
            }
        } else if model.upcoming.isEmpty {
            Text("No meetings today")
        } else {
            ForEach(model.upcoming) { meeting in
                if let link = meeting.link {
                    Button(rowTitle(meeting)) {
                        Task { await MeetingLink.open(link) }
                    }
                } else {
                    // Обычной строкой, а не серой кнопкой: встреча без ссылки —
                    // это нормальное напоминание, а не сломанный пункт меню.
                    Text(rowTitle(meeting))
                }
            }
        }

        Divider()

        Button("Settings…") {
            openSettings()
            // Окно настроек открывается, но не становится key: LSUIElement-приложение
            // само вперёд не выходит.
            NSApp.activate(ignoringOtherApps: true)
            model.syncSettings()
        }
        .keyboardShortcut(",")

        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func rowTitle(_ meeting: Meeting) -> String {
        let time = meeting.start.formatted(date: .omitted, time: .shortened)
        return "\(time)  \(meeting.title)"
    }
}
