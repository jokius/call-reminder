import SwiftUI

/// Крупная кнопка во весь размах окна: в него смотрят с другого конца комнаты
/// и в спешке, поэтому цель для попадания должна быть большой, а цвет —
/// говорить о действии раньше, чем прочитан текст.
struct BigActionButton: ButtonStyle {
    let color: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 440, height: 84)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color.opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.25))
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AlertView: View {
    let meeting: Meeting
    let onJoin: @MainActor () -> Void
    let onSkip: @MainActor () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 28) {
                // TimelineView, а не вычисление при отрисовке: `meeting` не меняется,
                // поэтому SwiftUI перерисовал бы текст ровно один раз и счётчик
                // застыл бы навсегда. Окно живёт до нажатия, так что показывать
                // «через 59 сек» спустя два часа — прямое враньё.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(alertCountdownText(start: meeting.start, now: context.date))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(meeting.title)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(meeting.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 28, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)

                VStack(spacing: 18) {
                    if meeting.link == nil {
                        // Подключаться некуда — незачем показывать мёртвую кнопку
                        // и заставлять выбирать между двумя одинаковыми исходами.
                        Button("Закрыть", action: onSkip)
                            .buttonStyle(BigActionButton(color: .accentColor))
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Подключиться", action: onJoin)
                            .buttonStyle(BigActionButton(color: .green))
                            .keyboardShortcut(.defaultAction)
                        Button("Пропустить", action: onSkip)
                            .buttonStyle(BigActionButton(color: .red))
                            .keyboardShortcut(.cancelAction)
                    }
                }
                .padding(.top, 12)

                if meeting.link == nil {
                    // .tertiary на чёрном фоне не читается — проверено рендером
                    Text("Ссылки на созвон в событии нет")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .foregroundStyle(.white)
            .padding(60)
        }
    }
}
