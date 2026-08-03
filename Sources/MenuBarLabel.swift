import Foundation

/// Максимальная длина названия в меню-баре. Больше — строка распирает панель.
private let maxTitleLength = 25

/// Текст статус-айтема. Чистая функция, чтобы формат проверялся тестом.
func menuBarText(next: Meeting?, now: Date, format: BarFormat) -> String {
    guard let next else { return "нет встреч" }

    let title = truncate(next.title)
    let minutes = Countdown.minutesUntil(next.start, from: now)
    let time = minutes <= 0 ? "сейчас" : compactDuration(minutes)

    switch format {
    case .timeAndTitle: return "\(time) · \(title)"
    case .titleOnly: return title
    case .timeOnly: return time
    }
}

/// Длительность в минутах — в читаемый вид. «143м» заставляет делить в уме,
/// поэтому от часа и выше разбиваем на часы и минуты.
func compactDuration(_ minutes: Int) -> String {
    guard minutes >= 60 else { return "\(minutes)м" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours)ч" : "\(hours)ч \(rest)м"
}

/// Подпись над названием встречи в полноэкранном окне.
///
/// Окно висит до тех пор, пока по нему не кликнут, поэтому текст обязан
/// оставаться честным и через час: после начала встречи счётчик идёт вверх.
func alertCountdownText(start: Date, now: Date) -> String {
    let seconds = Int(start.timeIntervalSince(now))
    if seconds >= 60 { return "через \(spelledDuration(seconds / 60))" }
    if seconds > 0 { return "через \(seconds) сек" }

    let elapsed = -seconds
    if elapsed < 60 { return "начинается сейчас" }
    return "идёт \(spelledDuration(elapsed / 60))"
}

/// То же самое, но словами и с пробелами — в полноэкранном окне место есть,
/// и «2 ч 36 мин» читается спокойнее, чем сжатое «2ч 36м» из меню-бара.
private func spelledDuration(_ minutes: Int) -> String {
    guard minutes >= 60 else { return "\(minutes) мин" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours) ч" : "\(hours) ч \(rest) мин"
}

private func truncate(_ title: String) -> String {
    guard title.count > maxTitleLength else { return title }
    return title.prefix(maxTitleLength).trimmingCharacters(in: .whitespaces) + "…"
}
