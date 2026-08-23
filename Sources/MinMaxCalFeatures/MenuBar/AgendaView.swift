import AppKit
import MinMaxCalDomain
import SwiftUI

public struct AgendaView: View {
    // MARK: Lifecycle

    public init(model: AgendaModel) {
        self.model = model
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    if let message = model.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                    if model.agenda.items.isEmpty {
                        emptyState
                    } else {
                        section(
                            "Today",
                            items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) == false },
                        )
                        section("Tomorrow", items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) })
                    }
                }
                .padding()
            }
            .frame(maxHeight: Self.maximumHeight)
            // The menu bar window proposes no height, so the list must
            // size itself to its rows rather than collapse to nothing.
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            footer
        }
        .frame(width: Self.width)
    }

    // MARK: Private

    private static let width: CGFloat = 360
    private static let maximumHeight: CGFloat = 480
    private static let sectionSpacing: CGFloat = 12
    private static let padding: CGFloat = 8

    @Environment(\.calendar)
    private var calendar
    @Environment(\.openSettings)
    private var openSettings

    private let model: AgendaModel

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Self.padding) {
            Text(model.hasSelection ? "Nothing upcoming today or tomorrow." : "No calendars selected.")
                .foregroundStyle(.secondary)
            if model.hasSelection == false {
                Button("Choose calendars…", action: showSettings)
                    .buttonStyle(.glass)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(action: showSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Settings")
            .keyboardShortcut(",")
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.glass)
        .padding(Self.padding)
    }

    @ViewBuilder
    private func section(_ title: String, items: [AgendaItem]) -> some View {
        if items.isEmpty == false {
            Text(title)
                .font(.headline)
            ForEach(items) { item in
                AgendaRow(
                    item: item,
                    now: model.now,
                    style: .agenda,
                    onJoin: model.join,
                    onComplete: { Task { await model.complete(item) } },
                )
            }
        }
    }

    private func showSettings() {
        NSApplication.shared.activate()
        openSettings()
    }
}
