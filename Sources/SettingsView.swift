import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let calendars: [CalendarInfo]

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    /// Уже сохранённое значение добавляется в список, даже если оно нестандартное:
    /// иначе Picker не нашёл бы совпадения и показал пустую строку.
    private var leadOptions: [Int] {
        Set(AppSettings.leadPresets + [settings.leadMinutes]).sorted()
    }

    var body: some View {
        Form {
            Section("Напоминание") {
                Picker("Показывать за", selection: $settings.leadMinutes) {
                    ForEach(leadOptions, id: \.self) { minutes in
                        Text("\(minutes) мин").tag(minutes)
                    }
                }
            }

            Section("Меню-бар") {
                Picker("Показывать", selection: $settings.barFormat) {
                    ForEach(BarFormat.allCases, id: \.self) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Календари") {
                if calendars.isEmpty {
                    Text("Нет доступных календарей").foregroundStyle(.secondary)
                } else {
                    ForEach(calendars) { calendar in
                        Toggle(isOn: binding(for: calendar.id)) {
                            // Название не уникально — показываем вместе с аккаунтом
                            Text("\(calendar.title)  ·  \(calendar.account)")
                        }
                    }
                    Text("Если не выбрано ничего — учитываются все календари.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Запускать при входе", isOn: $launchAtLogin)
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
                    Button("Разрешить в Системных настройках") { LaunchAtLogin.openSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
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
