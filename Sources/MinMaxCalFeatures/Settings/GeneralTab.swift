import MinMaxCalData
import MinMaxCalDomain
import SwiftUI

struct GeneralTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            login
            title
            permissions
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

    private var login: some View {
        Section {
            Toggle("Launch at login", isOn: $model.launchAtLogin)
            if model.loginItemStatus == .requiresApproval {
                LabeledContent("macOS needs you to approve the login item.") {
                    Button("Open Login Items", action: model.openLoginItemsSettings)
                        .buttonStyle(.glass)
                }
            }
        } footer: {
            Text("A takeover needs the app running, so it starts with you and stays in the menu bar.")
        }
    }

    private var title: some View {
        Section {
            Stepper(
                "Title length: \(String(model.titleLimit)) characters",
                value: $model.titleLimit,
                in: MenuBarTitle.limitRange,
            )
        } footer: {
            Text("Longer titles keep their start and end and drop the middle, so the menu bar never grows past this.")
        }
    }

    private var permissions: some View {
        Section {
            permission("Calendars", model.access.events, pane: "Privacy_Calendars")
            permission("Reminders", model.access.reminders, pane: "Privacy_Reminders")
        } footer: {
            Text("Full access to Calendars is needed to list anything; Reminders is optional.")
        }
    }

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
