import Foundation

/// Максимальная длина названия в меню-баре. Больше — строка распирает панель.
private let maxTitleLength = 25

/// Текст статус-айтема. Чистая функция, чтобы формат проверялся тестом.
func menuBarText(next: Meeting?, now: Date, format: BarFormat) -> String {
    guard let next else { return "нет встреч" }

    let title = truncate(next.title)
    guard format == .timeAndTitle else { return title }

    let minutes = Countdown.minutesUntil(next.start, from: now)
    return minutes <= 0 ? "сейчас · \(title)" : "\(minutes)м · \(title)"
}

/// Подпись над названием встречи в полноэкранном окне.
///
/// Окно висит до тех пор, пока по нему не кликнут, поэтому текст обязан
/// оставаться честным и через час: после начала встречи счётчик идёт вверх.
func alertCountdownText(start: Date, now: Date) -> String {
    let seconds = Int(start.timeIntervalSince(now))
    if seconds >= 60 { return "через \(seconds / 60) мин" }
    if seconds > 0 { return "через \(seconds) сек" }

    let elapsed = -seconds
    if elapsed < 60 { return "начинается сейчас" }
    let minutes = elapsed / 60
    if minutes < 60 { return "идёт \(minutes) мин" }
    return "идёт \(minutes / 60) ч \(minutes % 60) мин"
}

private func truncate(_ title: String) -> String {
    guard title.count > maxTitleLength else { return title }
    return title.prefix(maxTitleLength).trimmingCharacters(in: .whitespaces) + "…"
}
