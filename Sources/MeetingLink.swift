import AppKit
import Foundation

/// Всё, что связано со ссылкой на созвон: где её взять в событии и как открыть.
enum MeetingLink {

    /// Хосты, по которым понятно, что ссылка ведёт на созвон, а не на вики.
    /// Домены Zoom взяты из его собственного парсера (zNetUtils), а не выдуманы:
    /// одним `zoom.us` теряются корпоративные и государственные ссылки.
    private static let meetingHostSuffixes = [
        "zoom.us", "zoomgov.com", "zoomgov.mil", "zoom.com", "zoom.cn",
        "meetzoom.net", "zoomconnector.com",
        "teams.microsoft.com", "teams.live.com", "teams.microsoft.us",
        "meet.google.com", "webex.com", "whereby.com",
    ]

    private static func isMeetingHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        guard meetingHostSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else {
            return false
        }
        // У Teams на том же хосте живут служебные страницы: рядом со ссылкой
        // на встречу в приглашении лежит `/meetingOptions/`. Присоединиться
        // можно двумя путями — старым `/l/meetup-join/...` и новым `/meet/<id>`,
        // оба встречаются в одном календаре.
        if host.contains("teams.") {
            return url.path.hasPrefix("/l/") || url.path.hasPrefix("/meet/")
        }
        return true
    }

    /// В заметках ссылку часто заворачивают в угловые скобки, и NSDataDetector
    /// прихватывает всё, что идёт следом, вместе со второй ссылкой.
    /// Замерено: `…/meet/439387043134551?p=VqlCBNiRnyp6GVNMCW%3Chttps://eur05…`.
    private static func trimTrailingJunk(_ url: URL) -> URL {
        let text = url.absoluteString
        guard let cut = text.range(of: "%3C", options: .caseInsensitive) ?? text.range(of: "<") else {
            return url
        }
        return URL(string: String(text[text.startIndex..<cut.lowerBound])) ?? url
    }

    /// Корпоративная защита Exchange заворачивает ссылки в приглашениях:
    /// `eur05.safelinks.protection.outlook.com/?url=<исходный>`. Хост обёртки
    /// не похож на созвон, поэтому без разворачивания правило выбора не работает
    /// вовсе — а первой в заметках лежит ссылка на страницу справки Teams,
    /// и открывалась именно она.
    private static func unwrapSafeLink(_ url: URL) -> URL {
        guard url.host?.lowercased().hasSuffix("safelinks.protection.outlook.com") == true,
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let inner = comps.queryItems?.first(where: { $0.name == "url" })?.value,
            let unwrapped = URL(string: inner)
        else { return url }
        return unwrapped
    }

    private static func links(in text: String?) -> [URL] {
        guard let text, !text.isEmpty,
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }

    /// Ссылка на созвон из полей события. Порядок: собственное поле URL,
    /// затем location, затем notes. Внутри текста предпочитаем ссылку с
    /// известным хостом созвона — в заметках обычно ещё лежат вики и таск-трекер.
    static func extract(url: URL?, location: String?, notes: String?) -> URL? {
        // Поле url не имеет безусловного приоритета: замер на календаре пользователя
        // показал 3 события, где там лежит не созвон (кастомная схема таск-трекера).
        // Правило одно для всех источников — ссылка на созвон важнее любой другой.
        var candidates = links(in: location) + links(in: notes)
        if let url { candidates.insert(url, at: 0) }
        // Разворачиваем до выбора: иначе у всех кандидатов один и тот же
        // хост обёртки и отличить встречу от справки невозможно.
        candidates = candidates.map { trimTrailingJunk(unwrapSafeLink($0)) }
        return candidates.first(where: isMeetingHost) ?? candidates.first
    }

    /// Нативный deep link, если он есть. nil — открывать исходный https.
    ///
    /// Teams здесь намеренно нет. Обе формы `msteams:` — и с хостом, и без —
    /// система резолвит в Teams.app, поэтому hasHandler считает их рабочими,
    /// но сам клиент такую ссылку не разбирает и уводит на страницу справки.
    /// Проверено на живой ссылке из календаря дважды. Похоже, страница
    /// `teams.microsoft.com/l/meetup-join` не редирект, а серверный резолв:
    /// клиенту уходит уже её собственный deep link с токенами, а собрать его
    /// локально нельзя — та же история, что с персональными ссылками Zoom.
    /// https открывается в браузере и сам перекидывает в приложение.
    ///
    /// ponytail: формат Zoom тоже приходит с сервера и может смениться без
    /// апдейта клиента, поэтому fallback на https в `open(_:)` обязателен.
    static func nativeDeepLink(for url: URL) -> URL? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let host = comps.host?.lowercased(),
            comps.scheme?.hasPrefix("http") == true
        else { return nil }

        return zoomDeepLink(host: host, comps: comps)
    }

    private static let zoomSuffixes = [
        "zoom.us", "zoomgov.com", "zoomgov.mil", "zoom.com", "zoom.cn",
        "meetzoom.net", "zoomconnector.com",
    ]

    private static func zoomDeepLink(host: String, comps: URLComponents) -> URL? {
        guard zoomSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return nil }
        // /j/<id> обычная встреча, /w/<id> вебинар, /s/<id> старт хостом.
        // /my/<vanity> сюда не попадает намеренно: имя разворачивает только сервер.
        let parts = comps.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2, ["j", "w", "s"].contains(parts[0]),
            parts[1].allSatisfy(\.isNumber)
        else { return nil }

        var out = URLComponents()
        // На macOS сам Zoom генерит zoomus, а не zoommtg — zoommtg это windows/linux-ветка
        // его лаунчера. Обе схемы зарегистрированы приложением, но идём тем же путём, что и веб.
        out.scheme = "zoomus"
        out.host = host
        out.path = "/join"
        var query = [URLQueryItem(name: "confno", value: parts[1])]
        for name in ["pwd", "tk"] {
            if let value = comps.queryItems?.first(where: { $0.name == name })?.value, !value.isEmpty {
                query.append(URLQueryItem(name: name, value: value))
            }
        }
        // остальные параметры (_x_zm_rtaid и прочий трекинг редиректа) выбрасываем
        out.queryItems = query
        return out.url
    }

    /// Человеческое имя сервиса — строкой под названием встречи.
    /// Для незнакомого хоста возвращаем сам хост: это честнее, чем безликое
    /// «Созвон», и сразу видно, куда именно поведёт кнопка.
    static func serviceName(for url: URL) -> String {
        guard let host = url.host?.lowercased() else { return String(localized: "Call") }
        let known: [(suffix: String, name: String)] = [
            ("meet.google.com", "Google Meet"),
            ("teams.microsoft.com", "Microsoft Teams"),
            ("teams.live.com", "Microsoft Teams"),
            ("teams.microsoft.us", "Microsoft Teams"),
            ("webex.com", "Webex"),
            ("whereby.com", "Whereby"),
            ("meet.jit.si", "Jitsi"),
            ("discord.com", "Discord"),
            ("slack.com", "Slack"),
            ("telemost.yandex.ru", "Телемост"),
            ("ktalk.ru", "Контур.Толк"),
        ]
        if let match = known.first(where: { host == $0.suffix || host.hasSuffix("." + $0.suffix) }) {
            return match.name
        }
        if zoomSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return "Zoom" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Есть ли в системе приложение, которое возьмёт эту схему. Синхронно, ничего не запускает.
    static func hasHandler(_ url: URL) -> Bool {
        NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    /// Открывает deep link, если его есть кому обработать, иначе исходный https.
    /// Возвращает false, только если не открылось вообще ничего.
    @discardableResult
    static func open(_ link: URL) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let deepLink = nativeDeepLink(for: link)
        let target = deepLink.map { hasHandler($0) ? $0 : link } ?? link
        do {
            _ = try await NSWorkspace.shared.open(target, configuration: configuration)
            return true
        } catch {
            guard target != link else { return false }
            return (try? await NSWorkspace.shared.open(link, configuration: configuration)) != nil
        }
    }
}
