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

private func truncate(_ title: String) -> String {
    guard title.count > maxTitleLength else { return title }
    return title.prefix(maxTitleLength).trimmingCharacters(in: .whitespaces) + "…"
}
