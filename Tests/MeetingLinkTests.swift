import Foundation
import Testing

@testable import callReminder

@Suite("Извлечение ссылки на встречу")
struct MeetingLinkExtractTests {

    @Test("поле url важнее location и notes")
    func urlFieldWins() {
        let got = MeetingLink.extract(
            url: URL(string: "https://zoom.us/j/111"),
            location: "https://meet.google.com/abc-defg-hij",
            notes: "https://example.com/doc")
        #expect(got?.absoluteString == "https://zoom.us/j/111")
    }

    @Test("ссылка на встречу в notes важнее постороннего URL в location")
    func meetingHostBeatsPosition() {
        let got = MeetingLink.extract(
            url: nil,
            location: "https://confluence.corp/page",
            notes:
                "повестка тут https://confluence.corp/agenda\nзвонок https://teams.microsoft.com/l/meetup-join/x"
        )
        #expect(got?.host == "teams.microsoft.com")
    }

    @Test("если ссылки на встречу нет — берём первую попавшуюся")
    func fallbackToFirstLink() {
        let got = MeetingLink.extract(url: nil, location: "Переговорка 3", notes: "https://example.com/doc")
        #expect(got?.absoluteString == "https://example.com/doc")
    }

    @Test("нет ссылок вообще")
    func noLinks() {
        #expect(MeetingLink.extract(url: nil, location: "Переговорка 3", notes: nil) == nil)
    }
}

@Suite("Deep links")
struct MeetingLinkDeepLinkTests {

    @Test(
        "Zoom /j/ с паролем",
        arguments: [
            (
                "https://company.zoom.us/j/85512345678?pwd=abcXYZ",
                "zoomus://company.zoom.us/join?confno=85512345678&pwd=abcXYZ"
            ),
            (
                "https://zoom.us/j/85512345678",
                "zoomus://zoom.us/join?confno=85512345678"
            ),
            (
                "https://us02web.zoom.us/w/85512345678?tk=TOK&pwd=P",
                "zoomus://us02web.zoom.us/join?confno=85512345678&pwd=P&tk=TOK"
            ),
            (
                "https://zoom.us/s/85512345678",
                "zoomus://zoom.us/join?confno=85512345678"
            ),
            (
                "https://zoomgov.com/j/1600123456?pwd=Q",
                "zoomus://zoomgov.com/join?confno=1600123456&pwd=Q"
            ),
        ])
    func zoom(input: String, expected: String) throws {
        let url = try #require(URL(string: input))
        #expect(MeetingLink.nativeDeepLink(for: url)?.absoluteString == expected)
    }

    @Test("Zoom мусорные параметры редиректа выбрасываются")
    func zoomDropsTrackingParams() throws {
        let url = try #require(URL(string: "https://zoom.us/j/2351717870?_x_zm_rtaid=abc&_x_zm_rhtaid=920"))
        #expect(
            MeetingLink.nativeDeepLink(for: url)?.absoluteString
                == "zoomus://zoom.us/join?confno=2351717870")
    }

    @Test("Zoom personal link не конвертируется — его резолвит только сервер")
    func zoomPersonalLink() throws {
        let url = try #require(URL(string: "https://zoom.us/my/johndoe"))
        #expect(MeetingLink.nativeDeepLink(for: url) == nil)
    }

    @Test("Teams: percent-encoding в пути сохраняется байт в байт")
    func teams() throws {
        let raw =
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC%40thread.v2/0"
            + "?context=%7b%22Tid%22%3a%22t%22%7d"
        let url = try #require(URL(string: raw))
        let got = MeetingLink.nativeDeepLink(for: url)?.absoluteString
        #expect(
            got == "msteams:/l/meetup-join/19%3ameeting_ABC%40thread.v2/0?context=%7b%22Tid%22%3a%22t%22%7d")
    }

    @Test(
        "Google Meet и всё прочее остаются https",
        arguments: [
            "https://meet.google.com/abc-defg-hij",
            "https://example.com/whatever",
        ])
    func noDeepLink(input: String) throws {
        let url = try #require(URL(string: input))
        #expect(MeetingLink.nativeDeepLink(for: url) == nil)
    }
}
