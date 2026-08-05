import AppKit
import Testing

@testable import callReminder

@Suite("Ресурсы бандла")
struct AssetsTests {

    @Test("иконка трея есть в каталоге ассетов")
    func trayIconExists() throws {
        // Опечатку в имени ассета SwiftUI не показывает никак: Image("Опечатка")
        // молча рисует пустоту, и трей просто остаётся без иконки.
        let image = try #require(NSImage(named: "TrayIcon"), "ассет TrayIcon не найден в бандле")
        #expect(image.size.width > 0)
    }

    @Test("иконка трея — template, иначе macOS не перекрасит её под тёмную тему")
    func trayIconIsTemplate() throws {
        let image = try #require(NSImage(named: "TrayIcon"))
        #expect(image.isTemplate)
    }

    @Test("иконка приложения на месте")
    func appIconExists() throws {
        let image = try #require(NSImage(named: "AppIcon"), "ассет AppIcon не найден в бандле")
        #expect(image.size.width > 0)
    }
}
