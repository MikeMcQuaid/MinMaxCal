import MinMaxCalDomain
import SwiftUI

struct MatchingTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                TextField("Generic titles", text: genericTitles)
            } footer: {
                Text("Events with these titles, or no title, merge into a real meeting at the same time.")
                Text("Separate with commas.")
            }
            Section {
                TextField("Home terms", text: homeTerms)
            } footer: {
                Text("Dropped from locations because they only say where you already are.")
                Text("End a term with * to match a prefix such as a postcode.")
                Text("Separate with commas.")
            }
            Section {
                TextField("Jitsi hosts", text: jitsiHosts)
            } footer: {
                Text("Links on these hosts open in Microsoft Edge, as \(MatchingRules.builtInJitsiHost) always does.")
                Text("Separate with commas.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    private var genericTitles: Binding<String> {
        Binding(
            get: { model.rules.genericTitles.joined(separator: ", ") },
            set: { model.rules.genericTitles = ListField.strings(from: $0) },
        )
    }

    private var homeTerms: Binding<String> {
        Binding(
            get: { model.rules.homeTerms.joined(separator: ", ") },
            set: { model.rules.homeTerms = ListField.strings(from: $0) },
        )
    }

    private var jitsiHosts: Binding<String> {
        Binding(
            get: { model.rules.jitsiHosts.joined(separator: ", ") },
            set: { model.rules.jitsiHosts = ListField.strings(from: $0) },
        )
    }
}
