import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let calendars: [CalendarInfo]

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    /// Язык на момент открытия окна: пока выбор совпадает с ним, перезапускать нечего.
    @State private var initialLanguage: AppLanguage?

    private static let privacyPolicy = URL(
        string: "https://github.com/jokius/call-reminder/blob/main/PRIVACY.md")

    /// Уже сохранённое значение добавляется в список, даже если оно нестандартное:
    /// иначе Picker не нашёл бы совпадения и показал пустую строку.
    private var leadOptions: [Int] {
        Set(AppSettings.leadPresets + [settings.leadMinutes]).sorted()
    }

    var body: some View {
        Form {
            Section("Reminder") {
                Picker("Notify before", selection: $settings.leadMinutes) {
                    ForEach(leadOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            }

            Section("Language") {
                Picker("Language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.label).tag(language)
                    }
                }
                // Язык подхватывается бандлом только на старте, поэтому просто
                // менять пикер недостаточно — нужен новый процесс.
                if settings.language != initialLanguage {
                    HStack {
                        Text("Restart to apply the new language")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart") { AppRestart.now() }
                    }
                }
            }

            Section("Menu bar") {
                Picker("Show", selection: $settings.barFormat) {
                    ForEach(BarFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Calendars") {
                if calendars.isEmpty {
                    Text("No calendars available").foregroundStyle(.secondary)
                } else {
                    ForEach(calendars) { calendar in
                        Toggle(isOn: binding(for: calendar.id)) {
                            // Название не уникально — показываем вместе с аккаунтом
                            Text("\(calendar.title)  ·  \(calendar.account)")
                        }
                    }
                    Text("Only checked calendars are used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                            launchError = nil
                        } catch {
                            launchAtLogin = LaunchAtLogin.isEnabled
                            launchError = error.localizedDescription
                        }
                    }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
                if LaunchAtLogin.requiresApproval {
                    Button("Allow in System Settings") { LaunchAtLogin.openSettings() }
                }
                // Apple требует политику приватности не только в метаданных стора,
                // но и внутри приложения, «easily accessible» (гайдлайн 5.1.1(i)).
                if let policy = Self.privacyPolicy {
                    Link("Privacy Policy", destination: policy)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { initialLanguage = initialLanguage ?? settings.language }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { settings.selectedCalendarIDs.contains(id) },
            set: { isOn in
                if isOn {
                    settings.selectedCalendarIDs.insert(id)
                } else {
                    settings.selectedCalendarIDs.remove(id)
                }
            })
    }
}
