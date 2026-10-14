import AppKit
import MinMaxCalAgenda
import SwiftUI

struct AboutTab: View {
    // MARK: Internal

    var body: some View {
        Form {
            Section {
                HStack(spacing: Self.spacing) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: Self.iconSize, height: Self.iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text("MinMaxCal")
                            .font(.title2.bold())
                        Text("Version \(Self.info("CFBundleShortVersionString") ?? "unknown")")
                        if let copyright = Self.info("NSHumanReadableCopyright") {
                            Text(copyright)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                AboutLinks()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    private static let iconSize: CGFloat = 64
    private static let spacing: CGFloat = 12

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
