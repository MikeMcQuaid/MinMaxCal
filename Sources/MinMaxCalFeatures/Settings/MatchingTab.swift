import MinMaxCalAgenda
import SwiftUI

struct MatchingTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            MatchingFields(rules: $model.rules)
        }
        .formStyle(.grouped)
    }
}
