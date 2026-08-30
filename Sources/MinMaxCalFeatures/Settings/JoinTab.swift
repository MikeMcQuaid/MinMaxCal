import MinMaxCalDomain
import SwiftUI

struct JoinTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                ForEach(Self.services, id: \.self) { service in
                    Picker(service.name, selection: model.app(for: service)) {
                        Text("Default Browser").tag(nil as String?)
                        Divider()
                        ForEach(model.joinApps(for: service), id: \.bundleIdentifier) { app in
                            Text(app.name).tag(app.bundleIdentifier as String?)
                        }
                    }
                }
            } footer: {
                Text("Each kind of call opens in the app chosen here, or the default browser when that app is missing.")
                Text("Zoom and Teams open straight into the meeting with its passcode; a browser gets the web address.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    private static let services: [JoinLink.Service] = [.zoom, .teams, .meet, .jitsi, .facetime, .other]
}
