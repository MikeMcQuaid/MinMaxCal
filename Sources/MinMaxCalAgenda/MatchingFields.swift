import MinMaxCalDomain
import SwiftUI

/// Matching and location rules, committed when editing ends.
public struct MatchingFields: View {
    // MARK: Lifecycle

    public init(rules: Binding<MatchingRules>) {
        _rules = rules
    }

    // MARK: Public

    public var body: some View {
        Group {
            Section {
                TextField("Generic titles", value: $rules.genericTitles, format: ListField.Strings())
                    .labelsHidden()
            } header: {
                Text("Generic titles")
            } footer: {
                Text("Events with these titles, or no title, merge into a real meeting at the same time.")
                Text("Separate with commas and press Return.")
            }
            Section {
                TextField("Home terms", value: $rules.homeTerms, format: ListField.Strings())
                    .labelsHidden()
            } header: {
                Text("Home terms")
            } footer: {
                Text("Dropped from locations because they only say where you already are.")
                Text("End a term with * to match a prefix such as a postcode.")
                Text("Separate with commas and press Return.")
            }
        }
        .autocorrectionDisabled()
    }

    // MARK: Private

    @Binding private var rules: MatchingRules
}
