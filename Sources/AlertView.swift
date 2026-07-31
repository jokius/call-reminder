import SwiftUI

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

                HStack(spacing: 16) {
                    Button("Подключиться", action: onJoin)
                        .keyboardShortcut(.defaultAction)
                        .disabled(meeting.link == nil)
                    Button("Пропустить", action: onSkip)
                        .keyboardShortcut(.cancelAction)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .padding(.top, 12)

                if meeting.link == nil {
                    Text("В событии нет ссылки на созвон")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.white)
            .padding(60)
        }
    }
}
