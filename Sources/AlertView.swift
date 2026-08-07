import AppKit
import SwiftUI

/// Палитра экрана напоминания — вытащена из макета, чтобы цвета не расползались
/// по вьюхе магическими литералами.
private enum Palette {
    static let amber = Color(red: 0.949, green: 0.659, blue: 0.110)  // #F2A81C
    static let amberText = Color(red: 0.969, green: 0.780, blue: 0.404)  // #F7C767
    static let onAmber = Color(red: 0.078, green: 0.149, blue: 0.180)  // #14262E
    static let title = Color(red: 0.949, green: 0.965, blue: 0.969)  // #F2F6F7
    static let subtitle = Color(red: 0.941, green: 0.969, blue: 0.973)  // #F0F7F8

    static let backdropTop = Color(red: 0.114, green: 0.290, blue: 0.345)  // #1D4A58
    static let backdropMid = Color(red: 0.043, green: 0.169, blue: 0.212)  // #0B2B36
    static let backdropBottom = Color(red: 0.039, green: 0.125, blue: 0.157)  // #0A2028
    static let glowInner = Color(red: 0.067, green: 0.227, blue: 0.275)  // #113A46
    static let glowOuter = Color(red: 0.020, green: 0.067, blue: 0.082)  // #051115
}

/// Состояние плашки над названием. В макете их три, и отличаются они
/// не только текстом: чем ближе встреча, тем плотнее цвет.
private enum Urgency {
    case upcoming  // ещё есть время — полупрозрачный янтарь
    case now  // началась — сплошной янтарь
    case noLink  // подключаться некуда — торопиться незачем, цвет уходит в серый

    var background: Color {
        switch self {
        case .upcoming: Palette.amber.opacity(0.14)
        case .now: Palette.amber
        case .noLink: .white.opacity(0.07)
        }
    }

    var border: Color {
        switch self {
        case .upcoming: Palette.amber.opacity(0.32)
        case .now: .clear
        case .noLink: .white.opacity(0.14)
        }
    }

    var dot: Color {
        switch self {
        case .upcoming: Palette.amber
        case .now: Palette.onAmber
        case .noLink: Palette.subtitle.opacity(0.5)
        }
    }

    var text: Color {
        switch self {
        case .upcoming: Palette.amberText
        case .now: Palette.onAmber
        case .noLink: Palette.subtitle.opacity(0.72)
        }
    }
}

/// Главная кнопка: янтарная, шире второй. Одно действие на экране —
/// подключиться, поэтому в спешке палец идёт именно сюда.
private struct PrimaryActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 25, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.onAmber)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.amber.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Второстепенная кнопка: только обводка, чтобы не спорить с главной.
private struct SecondaryActionButton: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 25, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Palette.title : Palette.title.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.03 : (prominent ? 0.07 : 0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(prominent ? 0.20 : 0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Подсказка клавиши внутри кнопки: ⏎ и esc.
private struct KeyHint: View {
    let symbol: String
    var onAmber = false

    var body: some View {
        Text(symbol)
            .font(.system(size: symbol.count > 1 ? 15 : 17, weight: .medium, design: .rounded))
            .frame(height: 30)
            .padding(.horizontal, symbol.count > 1 ? 9 : 8)
            .frame(minWidth: symbol.count > 1 ? 0 : 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(onAmber ? Palette.onAmber.opacity(0.16) : .white.opacity(0.09))
            )
            .opacity(onAmber ? 0.75 : 0.8)
    }
}

/// Геометрия карточки из макета. Ширина фиксирована, поэтому доли кнопок
/// считаются явно: layoutPriority у SwiftUI — не flex-grow, он отдаёт всё
/// место приоритетной вьюхе, и вторая кнопка схлопывается в полоску.
private enum Layout {
    static let cardWidth: CGFloat = 860
    static let cardPadding: CGFloat = 64
    static let buttonGap: CGFloat = 16
    static let primaryFlex: CGFloat = 1.7

    static var buttonsWidth: CGFloat { cardWidth - cardPadding * 2 - buttonGap }
    static var primaryWidth: CGFloat { buttonsWidth * primaryFlex / (primaryFlex + 1) }
    static var secondaryWidth: CGFloat { buttonsWidth / (primaryFlex + 1) }
}

struct AlertView: View {
    let meeting: Meeting
    let onJoin: @MainActor () -> Void
    let onSkip: @MainActor () -> Void

    private var urgency: Urgency {
        if meeting.link == nil { return .noLink }
        return meeting.start.timeIntervalSinceNow <= 0 ? .now : .upcoming
    }

    /// Строка под названием: интервал, длительность и куда идём.
    /// Причина «ссылки нет» встаёт на место сервиса, а не отдельной подписью.
    private var metaParts: [String] {
        [
            meetingTimeRange(start: meeting.start, end: meeting.end),
            meetingDuration(start: meeting.start, end: meeting.end),
            meeting.link.map(MeetingLink.serviceName(for:)) ?? "Ссылки на созвон в событии нет",
        ]
    }

    var body: some View {
        ZStack {
            backdrop
            card
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.backdropTop, Palette.backdropMid, Palette.backdropBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // Свечение сверху по центру — взгляд идёт к карточке, а не к краям.
            RadialGradient(
                colors: [Palette.glowInner.opacity(0.90), Palette.glowOuter.opacity(0.965)],
                center: .top, startRadius: 0, endRadius: 900)
        }
        .ignoresSafeArea()
    }

    private var card: some View {
        VStack(spacing: 30) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }

            // Счётчик живой: meeting не меняется, и без TimelineView текст
            // застыл бы навсегда — окно висит до нажатия.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                countdownBadge(now: context.date)
            }

            Text(meeting.title)
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .tracking(-1.5)
                .foregroundStyle(Palette.title)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 14) {
                ForEach(Array(metaParts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("·").opacity(0.45)
                    }
                    Text(part)
                }
            }
            .font(.system(size: 21, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Palette.subtitle.opacity(0.6))

            actions
        }
        .padding(.top, 60)
        .padding(.horizontal, Layout.cardPadding)
        .padding(.bottom, 44)
        .frame(width: Layout.cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func countdownBadge(now: Date) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(urgency.dot)
                .frame(width: 9, height: 9)
            Text(alertCountdownText(start: meeting.start, now: now))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(urgency.text)
        }
        .frame(height: 44)
        .padding(.horizontal, 22)
        .background(Capsule().fill(urgency.background))
        .overlay(Capsule().stroke(urgency.border, lineWidth: 1))
    }

    private var actions: some View {
        HStack(spacing: Layout.buttonGap) {
            if meeting.link == nil {
                Button(action: onSkip) {
                    HStack(spacing: 14) {
                        Text("Закрыть")
                        KeyHint(symbol: "esc")
                    }
                }
                .buttonStyle(SecondaryActionButton(prominent: true))
            } else {
                Button(action: onJoin) {
                    HStack(spacing: 14) {
                        Text("Подключиться")
                        KeyHint(symbol: "⏎", onAmber: true)
                    }
                }
                .buttonStyle(PrimaryActionButton())
                .frame(width: Layout.primaryWidth)

                Button(action: onSkip) {
                    HStack(spacing: 14) {
                        Text("Пропустить")
                        KeyHint(symbol: "esc")
                    }
                }
                .buttonStyle(SecondaryActionButton())
                .frame(width: Layout.secondaryWidth)
            }
        }
        .padding(.top, 10)
    }
}
