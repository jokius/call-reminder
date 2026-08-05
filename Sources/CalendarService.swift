import EventKit
import Foundation

/// Единственная точка общения с EventKit.
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var observer: (any NSObjectProtocol)?

    /// Дёргается при любом изменении календаря. Приходит в том числе сразу
    /// после выдачи доступа — обработчик должен быть к этому готов.
    var onChange: (@MainActor () -> Void)?

    static var authorization: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    // Обычный deinit не компилируется в Swift 6.2+: обращение к не-Sendable
    // свойству из nonisolated deinit — ошибка.
    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Календари для списка в настройках. Ключ — только `id`: у пользователя
    /// бывает несколько календарей с одинаковым названием.
    func calendars() -> [CalendarInfo] {
        store.calendars(for: .event)
            .map {
                CalendarInfo(id: $0.calendarIdentifier, title: $0.title, account: $0.source?.title ?? "—")
            }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
    }

    /// Встречи из выбранных календарей до конца сегодняшнего дня.
    /// Пустой `calendarIDs` означает «все календари».
    func upcoming(now: Date = Date(), calendarIDs: Set<String>) -> [Meeting] {
        let selected = store.calendars(for: .event)
            .filter { calendarIDs.isEmpty || calendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return [] }

        let predicate = store.predicateForEvents(
            withStart: now, end: endOfDay(from: now), calendars: selected)

        return store.events(matching: predicate)
            // Предикат включает событие, закончившееся ровно в now — замерено.
            .filter { $0.endDate > now }
            .filter { shouldRemind(candidate($0)) }
            .map(meeting(from:))
            .sorted { $0.start < $1.start }
    }

    private func candidate(_ event: EKEvent) -> EventCandidate {
        EventCandidate(
            isAllDay: event.isAllDay,
            // Заголовок EKEvent.h честно пишет, что единственный надёжный статус — canceled.
            isCancelled: event.status == .canceled,
            participation: participation(event),
            availability: availability(event))
    }

    private func participation(_ event: EKEvent) -> MyParticipation {
        guard let attendees = event.attendees, !attendees.isEmpty else { return .notInvited }
        // isCurrentUser — единственный надёжный способ найти себя: у Exchange
        // несколько SMTP-алиасов, сравнивать адреса руками бессмысленно.
        // Замерено: находит себя в 435 из 442 событий с участниками; остальные 7 —
        // рассылки на distribution list, где меня в списке физически нет.
        guard let me = attendees.first(where: \.isCurrentUser) else { return .notListed }
        switch me.participantStatus {
        case .pending: return .pending
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        default: return .unknown
        }
    }

    private func availability(_ event: EKEvent) -> Availability {
        switch event.availability {
        case .busy: return .busy
        case .free: return .free
        default: return .other
        }
    }

    private func meeting(from event: EKEvent) -> Meeting {
        // Явные типы обязательны: эти свойства null_unspecified, без указания
        // типа `??` даёт Optional и код не собирается.
        let start: Date = event.startDate
        let end: Date = event.endDate
        let occurrence: Date = event.occurrenceDate ?? start
        let rawID: String = event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier

        return Meeting(
            key: OccurrenceKey(
                seriesID: rawID.components(separatedBy: "/RID=")[0],
                calendarID: event.calendar?.calendarIdentifier ?? "",
                occurrence: occurrence),
            title: event.title ?? "Без названия",
            start: start,
            end: end,
            link: MeetingLink.extract(url: event.url, location: event.location, notes: event.notes))
    }
}
