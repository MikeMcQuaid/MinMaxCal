import MinMaxCalAgenda
import SwiftUI

struct MatchingTab: View {
    // swiftformat:disable:next privateSwiftUIDynamicProperties -- injected through the memberwise initialiser
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            MatchingFields(rules: $model.rules)
        }
        .formStyle(.grouped)
    }
}
