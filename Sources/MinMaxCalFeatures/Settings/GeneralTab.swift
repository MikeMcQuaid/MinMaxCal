import MinMaxCalData
import MinMaxCalDomain
import SwiftUI

struct GeneralTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section("Login") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                if model.loginItemStatus == .requiresApproval {
                    LabeledContent("macOS needs you to approve the login item.") {
                        Button("Open Login Items", action: model.openLoginItemsSettings)
                            .buttonStyle(.glass)
                    }
                }
            }
            Section("Menu bar") {
                Stepper(
                    "Title length: \(String(model.titleLimit)) characters",
                    value: $model.titleLimit,
                    in: MenuBarTitle.limitRange,
                )
            }
            Section("Permissions") {
                permission("Calendars", model.access.events, pane: "Privacy_Calendars")
                permission("Reminders", model.access.reminders, pane: "Privacy_Reminders")
            }
            if let message = model.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    @Environment(\.openURL)
    private var openURL

    private func permission(_ name: String, _ grant: AccessStatus.Grant, pane: String) -> some View {
        LabeledContent(name) {
            HStack {
                Text(Self.description(of: grant))
                    .foregroundStyle(.secondary)
                if grant.isFull == false, let url = Self.privacyPane(pane) {
                    Button("Open Privacy Settings") {
                        openURL(url)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private static func privacyPane(_ pane: String) -> URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }

    private static func description(of grant: AccessStatus.Grant) -> String {
        switch grant {
        case .full:
            "Full access"

        case .denied:
            "Denied"

        case .restricted:
            "Restricted"

        case .writeOnly:
            "Add only"

        case .notDetermined:
            "Not asked yet"
        }
    }
}
