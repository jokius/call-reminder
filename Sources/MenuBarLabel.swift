import Foundation

/// Максимальная длина названия в меню-баре. Больше — строка распирает панель.
private let maxTitleLength = 25

/// Текст статус-айтема. Чистая функция, чтобы формат проверялся тестом.
func menuBarText(next: Meeting?, now: Date, format: BarFormat) -> String {
    // Пусто, а не «нет встреч»: когда показывать нечего, в меню-баре
    // остаётся одна иконка и строка не занимает место зря.
    guard let next else { return "" }

    let title = truncate(next.title)
    let minutes = Countdown.minutesUntil(next.start, from: now)
    let time = minutes <= 0 ? String(localized: "now") : compactDuration(minutes)

    switch format {
    case .timeAndTitle: return "\(time) · \(title)"
    case .titleOnly: return title
    case .timeOnly: return time
    }
}

/// Длительность в минутах — в читаемый вид. «143м» заставляет делить в уме,
/// поэтому от часа и выше разбиваем на часы и минуты.
func compactDuration(_ minutes: Int) -> String {
    guard minutes >= 60 else { return String(localized: "\(minutes)m") }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? String(localized: "\(hours)h") : String(localized: "\(hours)h \(rest)m")
}

/// Подпись над названием встречи в полноэкранном окне.
///
/// Окно висит до тех пор, пока по нему не кликнут, поэтому текст обязан
/// оставаться честным и через час: после начала встречи счётчик идёт вверх.
func alertCountdownText(start: Date, now: Date) -> String {
    let seconds = Int(start.timeIntervalSince(now))
    if seconds >= 60 { return String(localized: "in \(spelledDuration(seconds / 60))") }
    if seconds > 0 { return String(localized: "in \(seconds) sec") }

    let elapsed = -seconds
    if elapsed < 60 { return String(localized: "starting now") }
    return String(localized: "running for \(spelledDuration(elapsed / 60))")
}

/// Интервал встречи строкой: «14:30 – 15:00».
func meetingTimeRange(start: Date, end: Date, locale: Locale = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
}

/// Сколько длится встреча: «30 мин», «1 ч», «1 ч 30 мин».
func meetingDuration(start: Date, end: Date) -> String {
    let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
    return spelledDuration(minutes)
}

/// То же самое, но словами и с пробелами — в полноэкранном окне место есть,
/// и «2 ч 36 мин» читается спокойнее, чем сжатое «2ч 36м» из меню-бара.
func spelledDuration(_ minutes: Int) -> String {
    guard minutes >= 60 else { return String(localized: "\(minutes) min") }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? String(localized: "\(hours) h") : String(localized: "\(hours) h \(rest) min")
}

private func truncate(_ title: String) -> String {
    guard title.count > maxTitleLength else { return title }
    return title.prefix(maxTitleLength).trimmingCharacters(in: .whitespaces) + "…"
}
