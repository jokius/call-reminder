# App Store Connect — данные для релиза 1.0.0

Скриншоты лежат в `docs/store/` (в гит не идут).

---

## Общее (одно на все языки)

| Поле | Значение |
|---|---|
| Bundle ID | `com.konayre.callreminder` |
| Primary Category | Productivity |
| Secondary Category | *(оставить пустым)* |
| Age Rating | 4+ |
| Price | $4.99 (Tier 5) |
| Copyright | 2026 Igor Kutiavin |
| Support URL | https://github.com/jokius/call-reminder/issues |
| Marketing URL | https://github.com/jokius/call-reminder |
| Privacy Policy URL | https://github.com/jokius/call-reminder/blob/main/PRIVACY.md |

**App Privacy → «Data Not Collected»** по всем категориям. Приложение не ходит в
сеть и не имеет entitlement на неё, так что это не обещание, а свойство сборки.

**Export Compliance** — вопроса не будет: `ITSAppUsesNonExemptEncryption: false`
уже в Info.plist.

---

## English

**Name**
```
Call Reminder
```

**Subtitle**
```
Meeting alerts you can't miss
```

**Keywords**
```
meeting,reminder,calendar,menubar,alert,standup,daily,agenda,schedule,notify,call
```

**Promotional Text**
```
A full-screen reminder before every call — impossible to miss, unlike a banner that slides away while you're heads-down in work.
```

**Description**
```
Call Reminder sits in your menu bar, shows the next meeting from your Calendar, and — a few minutes before it starts — takes over the whole screen so you cannot miss it.

Notification banners slide away while you are deep in work. A full-screen window does not.

WHAT MAKES IT DIFFERENT

• Covers everything, even full-screen apps. Watching a video, writing code in full screen, presenting — the reminder still appears on top.
• The counter stays honest. Once the meeting has started, it counts up, so you always see how late you are instead of a frozen "in 0 min".
• Zoom opens in the app, not the browser. Other services open by link.
• Meetings without a link are shown too — with a single Dismiss button, not a broken one.
• Keyboard first: Return joins, Escape skips.

WORKS QUIETLY

• No account, no sign-up, no cloud.
• No network at all. The app ships without the network entitlement, so it is technically incapable of sending your data anywhere.
• Events come from the system Calendar — which already syncs Google, iCloud and Exchange for you.

YOURS TO CONFIGURE

• Menu bar shows time and title, title only, or just time.
• Pick which calendars count.
• Choose how many minutes ahead to warn.
• Launch at login.
• Interface in English or Russian, switchable inside the app regardless of your system language.

OPEN SOURCE

The full source code is public at github.com/jokius/call-reminder under the MIT license. Every claim above can be verified, and if you would rather build it yourself, you can.
```

**What's New in This Version**
```
First release.
```

---

## Русский

**Name**
```
Call Reminder
```

**Subtitle**
```
Напоминание о созвонах
```

**Keywords**
```
встреча,созвон,напоминание,календарь,менюбар,будильник,дейли,расписание,планёрка
```

**Promotional Text**
```
Полноэкранное напоминание перед каждым созвоном — его невозможно пропустить, в отличие от баннера, который уезжает, пока вы заняты работой.
```

**Description**
```
Call Reminder живёт в строке меню, показывает ближайшую встречу из Календаря и за несколько минут до начала разворачивается на весь экран, чтобы вы её не пропустили.

Баннеры уведомлений уезжают, пока вы заняты. Полноэкранное окно — нет.

ЧЕМ ОТЛИЧАЕТСЯ

• Накрывает всё, включая полноэкранные приложения. Смотрите видео, пишете код в полный экран, показываете презентацию — напоминание всё равно окажется сверху.
• Счётчик не врёт. После начала встречи он считает вверх, и видно, на сколько вы опаздываете, а не застывшее «через 0 мин».
• Zoom открывается в приложении, а не в браузере. Остальные сервисы — ссылкой.
• Встречи без ссылки показываются тоже — с одной кнопкой «Закрыть», а не со сломанной.
• Всё с клавиатуры: Enter — подключиться, Esc — пропустить.

РАБОТАЕТ ТИХО

• Без учётной записи, без регистрации, без облака.
• Совсем без сети. У приложения нет даже права на сеть, поэтому отправить куда-то ваши данные оно технически неспособно.
• События берутся из системного Календаря — он и так синхронизирует Google, iCloud и Exchange.

НАСТРАИВАЕТСЯ

• В меню-баре — время и название, только название или только время.
• Выбор календарей, которые учитывать.
• За сколько минут предупреждать.
• Запуск при входе в систему.
• Интерфейс на русском или английском, переключается внутри приложения независимо от языка системы.

ОТКРЫТЫЙ КОД

Исходники открыты на github.com/jokius/call-reminder под лицензией MIT. Каждое утверждение выше можно проверить, а при желании — собрать приложение самому.
```

**What's New in This Version**
```
Первый релиз.
```
