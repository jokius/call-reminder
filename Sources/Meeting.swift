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

/// Мой ответ на приглашение.
enum MyParticipation: Sendable {
    case notInvited  // приглашения нет, это моё собственное событие
    case notListed  // участники есть, но меня среди них нет (рассылка на группу)
    case pending, accepted, declined, tentative, unknown
}

enum Availability: Sendable {
    case busy, free, other
}

/// Поля события, от которых зависит решение «напоминать или нет».
/// Отдельный тип нужен, чтобы правило было чистым и проверяемым тестом.
struct EventCandidate: Sendable {
    let isAllDay: Bool
    let isCancelled: Bool
    let participation: MyParticipation
    let availability: Availability
}

func shouldRemind(_ event: EventCandidate) -> Bool {
    if event.isAllDay { return false }
    if event.isCancelled { return false }
    if event.participation == .declined { return false }
    // «Свободен» само по себе не значит «не встреча»: замерено 8 из 41 таких
    // событий — принятые приглашения. Отсекаем только когда приглашения нет вовсе.
    if event.availability == .free, event.participation == .notInvited { return false }
    return true
}
