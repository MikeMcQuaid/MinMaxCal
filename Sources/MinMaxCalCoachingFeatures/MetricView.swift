import SwiftUI

struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(
            alignment: .leading,
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            spacing: 4,
        ) {
            Text(value)
                .font(.system(
                    .title,
                    design: .rounded,
                    weight: .semibold,
                ))
                .monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .accessibilityElement(children: .combine)
    }
}
