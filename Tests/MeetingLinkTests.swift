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

    @Test("посторонний url не перебивает ссылку на созвон в заметках")
    func foreignURLLosesToMeetingLink() {
        // На реальном календаре пользователя замерено 3 события, где в поле url
        // лежит кастомная схема таск-трекера, а не созвон.
        let got = MeetingLink.extract(
            url: URL(string: "todoist://task/9e94f7a3-397f-4980-a462-9d7358bca83e"),
            location: nil,
            notes: "звонок https://zoom.us/j/85512345678")
        #expect(got?.host == "zoom.us")
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

@Suite("Имя сервиса созвона")
struct ServiceNameTests {

    @Test(
        "известные сервисы",
        arguments: [
            ("https://meet.google.com/abc-defg-hij", "Google Meet"),
            ("https://zoom.us/j/85512345678", "Zoom"),
            ("https://company.zoom.us/j/123", "Zoom"),
            ("https://zoomgov.com/j/123", "Zoom"),
            ("https://teams.microsoft.com/l/meetup-join/x", "Microsoft Teams"),
            ("https://acme.webex.com/meet/x", "Webex"),
            ("https://telemost.yandex.ru/j/123", "Телемост"),
        ])
    func known(input: String, expected: String) throws {
        let url = try #require(URL(string: input))
        #expect(MeetingLink.serviceName(for: url) == expected)
    }

    @Test("незнакомый сервис показывается хостом — видно, куда поведёт кнопка")
    func unknownShowsHost() throws {
        let url = try #require(URL(string: "https://www.vaultconf.example.com/room/42"))
        #expect(MeetingLink.serviceName(for: url) == "vaultconf.example.com")
    }
}

@Suite("Длительность и интервал встречи")
struct MeetingTimingTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test(
        "длительность",
        arguments: [
            (30.0, "30 мин"),
            (60.0, "1 ч"),
            (90.0, "1 ч 30 мин"),
            (0.0, "0 мин"),
        ])
    func duration(minutes: Double, expected: String) {
        let end = epoch.addingTimeInterval(minutes * 60)
        #expect(meetingDuration(start: epoch, end: end) == expected)
    }

    @Test("конец раньше начала не даёт отрицательную длительность")
    func negativeDuration() {
        #expect(meetingDuration(start: epoch, end: epoch.addingTimeInterval(-600)) == "0 мин")
    }

    @Test("интервал разделён en-dash с пробелами")
    func timeRange() {
        let text = meetingTimeRange(
            start: epoch, end: epoch.addingTimeInterval(1800), locale: Locale(identifier: "ru_RU"))
        #expect(text.contains(" – "))
        #expect(text.split(separator: " – ").count == 2)
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

    @Test("Teams не превращаем в deep link — клиент не разбирает msteams-ссылки")
    func teamsStaysHTTPS() throws {
        // Проверено дважды на живой ссылке из календаря: и msteams:/l/...,
        // и msteams://teams.microsoft.com/l/... открывают страницу справки.
        // Система при этом резолвит обе в Teams.app, так что hasHandler
        // на них не спасает — единственный рабочий путь остаётся через https.
        let raw =
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC%40thread.v2/0"
            + "?context=%7b%22Tid%22%3a%22t%22%7d"
        let url = try #require(URL(string: raw))
        #expect(MeetingLink.nativeDeepLink(for: url) == nil)
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
