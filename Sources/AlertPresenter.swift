import AppKit
import SwiftUI

/// Borderless-окно по умолчанию не может стать key — тогда кнопки и Esc не работают.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Показывает полноэкранное окно поверх всего, включая чужой fullscreen.
@MainActor
final class AlertPresenter {
    private var windows: [KeyableWindow] = []
    private var previousApp: NSRunningApplication?
    private var screenObserver: (any NSObjectProtocol)?

    var isShowing: Bool { !windows.isEmpty }

    /// `false` — окно уже занято другой встречей и эту мы не показали.
    /// Врать тут нельзя: движок по `true` помечает встречу обработанной,
    /// и тихое «показал» означает потерянное напоминание о втором созвоне.
    @discardableResult
    func show(
        _ meeting: Meeting,
        onJoin: @escaping @MainActor () -> Void,
        onSkip: @escaping @MainActor () -> Void
    ) -> Bool {
        guard windows.isEmpty else { return false }

        let front = NSWorkspace.shared.frontmostApplication
        // Не запоминаем себя: иначе при закрытии «вернём» фокус приложению без окон
        // и человек будет тыкать в пустоту.
        previousApp = front == NSRunningApplication.current ? nil : front

        for screen in NSScreen.screens {
            let window = KeyableWindow(
                contentRect: screen.frame, styleMask: .borderless,
                backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.collectionBehavior = [
                .canJoinAllSpaces,  // не исчезнуть, если человек свайпнул в другой Space
                .fullScreenAuxiliary,
                .stationary,  // не уезжать в Mission Control
                .ignoresCycle,  // не мусорить в Cmd-`
            ]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.animationBehavior = .none
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: AlertView(meeting: meeting, onJoin: onJoin, onSkip: onSkip))
            // frame, не visibleFrame: иначе под menu bar останется полоса
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()  // этого достаточно, чтобы накрыть чужой fullscreen
            windows.append(window)
        }

        // Нужно только ради клавиатуры. Кооперативная NSApp.activate() для
        // LSUIElement-приложения молча не срабатывает — проверено.
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)

        // Воткнули монитор, пока окно висит — пересобрать окна.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isShowing else { return }
                self.dismiss()
                // dismiss() уже опустошил windows, так что show вернёт true;
                // читать тут нечего — это пересборка того же самого окна.
                self.show(meeting, onJoin: onJoin, onSkip: onSkip)
            }
        }

        return true
    }

    func dismiss() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        // Приложение могли закрыть, пока висело окно: activate() на мертвяке вернёт
        // false, и фокус останется на нас — LSUIElement без единого окна.
        if let previousApp, !previousApp.isTerminated { previousApp.activate() }
        previousApp = nil
    }
}
