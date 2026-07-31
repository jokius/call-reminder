import Foundation
import Testing

@testable import callReminder

@Suite("Строка в меню-баре")
struct MenuBarLabelTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func meeting(_ title: String, startsIn seconds: TimeInterval) -> Meeting {
        Meeting(
            key: OccurrenceKey(seriesID: title, calendarID: "cal", occurrence: epoch),
            title: title,
            start: epoch.addingTimeInterval(seconds),
            end: epoch.addingTimeInterval(seconds + 1800),
            link: nil)
    }

    @Test("время и название")
    func timeAndTitle() {
        let text = menuBarText(next: meeting("Standup", startsIn: 720), now: epoch, format: .timeAndTitle)
        #expect(text == "12м · Standup")
    }

    @Test("только название")
    func titleOnly() {
        let text = menuBarText(next: meeting("Standup", startsIn: 720), now: epoch, format: .titleOnly)
        #expect(text == "Standup")
    }

    @Test("встреча вот-вот начнётся")
    func startingNow() {
        let text = menuBarText(next: meeting("Standup", startsIn: 30), now: epoch, format: .timeAndTitle)
        #expect(text == "сейчас · Standup")
    }

    @Test("длинное название обрезается")
    func longTitleTruncated() {
        let long = String(repeating: "Очень длинное название ", count: 5)
        let text = menuBarText(next: meeting(long, startsIn: 720), now: epoch, format: .titleOnly)
        #expect(text.count <= 26)
        #expect(text.hasSuffix("…"))
    }

    @Test("встреч нет")
    func noMeetings() {
        #expect(menuBarText(next: nil, now: epoch, format: .timeAndTitle) == "нет встреч")
    }
}
