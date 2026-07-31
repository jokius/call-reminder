import AppKit
import Foundation

/// Какую встречу пора показать. Чистая функция: всё состояние на входе.
///
/// Показываем, когда `start - lead <= now < start`. Верхняя граница строгая —
/// уже начавшуюся встречу не догоняем: если приложение запустили посреди созвона,
/// выпрыгивать на весь экран поздно и незачем.
func meetingToShow(
    events: [Meeting], now: Date, lead: TimeInterval, handled: Set<OccurrenceKey>
) -> Meeting? {
    events
        .filter { !handled.contains($0.key) }
        .filter { $0.start.timeIntervalSince(now) <= lead && $0.start > now }
        .min { $0.start < $1.start }
}

/// Тикает раз в секунду и решает, когда звать `onShow`.
@MainActor
@Observable
final class ReminderEngine {
    private(set) var events: [Meeting] = []
    private(set) var now: Date = .now

    /// Показанные и пропущенные — одно множество: и то и другое значит «больше не всплывать».
    /// Не участвует в отрисовке, поэтому вне наблюдения — иначе `inout` уедет
    /// в сгенерированное computed-свойство.
    @ObservationIgnored private var handled: Set<OccurrenceKey>

    /// Возвращает, состоялся ли показ. false (окно занято другой встречей) значит
    /// «не считай обработанной» — иначе напоминание пропало бы навсегда.
    @ObservationIgnored var onShow: (@MainActor (Meeting) -> Bool)?
    @ObservationIgnored var reload: (@MainActor () -> [Meeting])?
    @ObservationIgnored var lead: TimeInterval = 60

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: (any NSObjectProtocol)?
    @ObservationIgnored private let storage: HandledStore

    init(storage: HandledStore = HandledStore()) {
        self.storage = storage
        handled = storage.load()
    }

    /// Ближайшая встреча — для строки в меню-баре.
    var next: Meeting? { events.first { $0.start > now } }

    func start() {
        refresh()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
        // Таймер во сне не тикает: после пробуждения пересчитываем немедленно,
        // не дожидаясь следующей секунды.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.tick()
            }
        }
    }

    // Обычный deinit не компилируется в Swift 6.2+: обращение к не-Sendable
    // свойству из nonisolated deinit — ошибка.
    isolated deinit {
        ticker?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    /// Перечитать события из календаря.
    func refresh() {
        guard let reload else { return }
        events = reload()
        storage.prune(keeping: events.map(\.key), from: &handled)
    }

    /// `now` параметром — чтобы тик проверялся тестом; таймер зовёт с дефолтом.
    func tick(now: Date = .now) {
        self.now = now
        guard let due = meetingToShow(events: events, now: now, lead: lead, handled: handled) else { return }
        // Помечаем только после подтверждённого показа: если презентер занят
        // соседней встречей, эта останется в очереди до следующего тика.
        guard onShow?(due) == true else { return }
        markHandled(due.key)
    }

    func markHandled(_ key: OccurrenceKey) {
        handled.insert(key)
        storage.save(handled)
    }
}

/// Хранит ключи уже показанных встреч между запусками.
struct HandledStore {
    private let defaults: UserDefaults
    private let key = "handledOccurrences"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Set<OccurrenceKey> {
        guard let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(Set<OccurrenceKey>.self, from: data)
        else { return [] }
        return decoded
    }

    func save(_ value: Set<OccurrenceKey>) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Выкидывает записи о встречах, которые давно прошли, чтобы множество не пухло вечно.
    func prune(keeping current: [OccurrenceKey], from handled: inout Set<OccurrenceKey>) {
        let cutoff = Date().addingTimeInterval(-86_400)
        let alive = Set(current)
        let before = handled.count
        handled = handled.filter { alive.contains($0) || $0.occurrence > cutoff }
        if handled.count != before { save(handled) }
    }
}
