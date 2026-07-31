import Foundation
import Testing

@testable import callReminder

@Test func countdownRoundsDown() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(Countdown.minutesUntil(now.addingTimeInterval(600), from: now) == 10)
    #expect(Countdown.minutesUntil(now.addingTimeInterval(59), from: now) == 0)
    #expect(Countdown.minutesUntil(now.addingTimeInterval(-30), from: now) == -1)
}
