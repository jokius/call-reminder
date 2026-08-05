import EventKit
import Foundation

/// Ключ конкретного повтора встречи.
///
/// Не `eventIdentifier`: у всех повторов серии он одинаковый, а как только повтор
/// становится detached (встречу перенесли), к нему дописывается `/RID=...` и
/// прежняя запись «уже показал» протухает. Замерено на 712 событиях:
/// eventIdentifier дал 328 уникальных значений, эта тройка — 712 и ноль коллизий.
struct OccurrenceKey: Hashable, Codable, Sendable {
    let seriesID: String
    let calendarID: String
    /// Исходно запланированный слот. Переживает перенос встречи.
    let occurrence: Date
}

/// Встреча в терминах приложения. EventKit дальше этого файла не течёт —
/// поэтому ReminderEngine тестируется без календаря и без прав доступа.
struct Meeting: Identifiable, Hashable, Sendable {
    let key: OccurrenceKey
    let title: String
    let start: Date
    let end: Date
    /// Исходная https-ссылка. В deep link превращается в момент открытия.
    let link: URL?

    var id: OccurrenceKey { key }
    var calendarID: String { key.calendarID }
}

/// Календарь для списка в настройках.
/// `id` — `calendarIdentifier`, и только он: у пользователя замерено два разных
/// календаря с одинаковым названием «Todoist», так что title как ключ не годится.
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let account: String
}

/// Полночь наступающих суток — граница списка «на сегодня».
///
/// Считается через Calendar, а не прибавлением 24 часов: в дни перехода на
/// летнее время сутки длятся 23 или 25 часов, и арифметика по секундам
/// промахнулась бы мимо полуночи на час.
func endOfDay(from now: Date, calendar: Calendar = .current) -> Date {
    let startOfToday = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: 1, to: startOfToday)
        ?? startOfToday.addingTimeInterval(86_400)
}

/// Мой ответ на приглашение.
enum MyParticipation: Sendable {
    case notInvited  // приглашения нет, это моё собственное событие
    case notListed  // участники есть, но меня среди них нет (рассылка на группу)
    case pending, accepted, declined, tentative, unknown
}

/// Поля события, от которых зависит решение «напоминать или нет».
/// Отдельный тип нужен, чтобы правило было чистым и проверяемым тестом.
struct EventCandidate: Sendable {
    let isAllDay: Bool
    let isCancelled: Bool
    let participation: MyParticipation
}

/// Отсеиваем только то, о чём напоминать заведомо нечего.
///
/// По `availability` не фильтруем вовсе: правило «свободен и без приглашения —
/// значит не встреча» отсекало на живом календаре обычные личные события
/// вроде «Регистрация» в собственном календаре. Праздники и дни рождения
/// и так уходят как all-day.
func shouldRemind(_ event: EventCandidate) -> Bool {
    if event.isAllDay { return false }
    if event.isCancelled { return false }
    if event.participation == .declined { return false }
    return true
}
