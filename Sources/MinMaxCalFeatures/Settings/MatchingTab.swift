import MinMaxCalDomain
import SwiftUI

struct MatchingTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                TextField("Generic titles", value: $model.rules.genericTitles, format: ListField.Strings())
            } footer: {
                Text("Events with these titles, or no title, merge into a real meeting at the same time.")
                Text("Separate with commas and press Return.")
            }
            Section {
                TextField("Home terms", value: $model.rules.homeTerms, format: ListField.Strings())
            } footer: {
                Text("Dropped from locations because they only say where you already are.")
                Text("End a term with * to match a prefix such as a postcode.")
                Text("Separate with commas and press Return.")
            }
        }
        .formStyle(.grouped)
    }
}
