import AppKit
import SwiftUI

/// Сколько минут осталось до `date`, округляя вниз. Вынесено отдельно,
/// чтобы форматирование строки в трее было проверяемо тестом.
enum Countdown {
    static func minutesUntil(_ date: Date, from now: Date) -> Int {
        Int((date.timeIntervalSince(now) / 60).rounded(.down))
    }
}

@main
struct CallReminderApp: App {
    var body: some Scene {
        MenuBarExtra("callReminder", systemImage: "calendar.badge.clock") {
            Button("Выход") { NSApplication.shared.terminate(nil) }
        }
    }
}
