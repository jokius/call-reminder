import Foundation
import Testing

@testable import callReminder

@Suite("Правила отбора событий")
struct EventFilterTests {

    private func candidate(
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        participation: MyParticipation = .notInvited,
        availability: Availability = .busy
    ) -> EventCandidate {
        EventCandidate(
            isAllDay: isAllDay, isCancelled: isCancelled,
            participation: participation, availability: availability)
    }

    @Test("обычная встреча проходит")
    func normal() {
        #expect(shouldRemind(candidate()))
    }

    @Test("событие на весь день не напоминаем")
    func allDay() {
        #expect(!shouldRemind(candidate(isAllDay: true)))
    }

    @Test("отменённую встречу не напоминаем")
    func cancelled() {
        #expect(!shouldRemind(candidate(isCancelled: true)))
    }

    @Test("отклонённое приглашение не напоминаем")
    func declined() {
        #expect(!shouldRemind(candidate(participation: .declined)))
    }

    @Test("принятое приглашение со статусом «свободен» всё равно напоминаем")
    func freeButAccepted() {
        // замерено: 8 из 41 free-событий — это принятые приглашения,
        // включая рабочие созвоны. Глушить .free вслепую нельзя.
        #expect(shouldRemind(candidate(participation: .accepted, availability: .free)))
    }

    @Test("«свободен» без приглашения — это не встреча")
    func freeAndNotInvited() {
        #expect(!shouldRemind(candidate(participation: .notInvited, availability: .free)))
    }
}
