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
                            date: nil,
                            items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) == false },
                        )
                        section(
                            "Tomorrow",
                            date: calendar.date(byAdding: .day, value: 1, to: model.now),
                            items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) },
                        )
                    }
                }
                .padding(Self.padding)
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

    private static let width: CGFloat = 420
    private static let maximumHeight: CGFloat = 480
    private static let sectionSpacing: CGFloat = 8
    private static let rowSpacing: CGFloat = 4
    private static let padding: CGFloat = 8
    private static let detailIndent: CGFloat = 20

    @Environment(\.calendar)
    private var calendar
    @Environment(\.openSettings)
    private var openSettings
    @State private var expanded: AgendaItem.ID?

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
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .labelStyle(.iconOnly)
            .help("Quit MinMaxCal")
            .keyboardShortcut("q")
        }
        .buttonStyle(.glass)
        .padding(Self.padding)
    }

    @ViewBuilder
    private func section(_ title: String, date: Date?, items: [AgendaItem]) -> some View {
        if items.isEmpty == false {
            HStack(alignment: .firstTextBaseline, spacing: Self.padding) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let date {
                    Text(DayHeading.text(for: date, calendar: calendar))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: AgendaItem) -> some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            AgendaRow(
                item: item,
                style: .agenda,
                onJoin: model.join,
                onComplete: { Task { await model.complete(item) } },
                onUncomplete: { Task { await model.uncomplete(item) } },
            )
            .contentShape(Rectangle())
            .onTapGesture { toggle(item) }
            .accessibilityAddTraits(.isButton)
            .contextMenu {
                Button(expanded == item.id ? "Hide Details" : "Show Details") { toggle(item) }
                Button("Preview Takeover") { model.preview(item) }
            }
            if expanded == item.id {
                ItemDetails(item: item, rules: model.rules)
                    .font(.callout)
                    .padding(.leading, Self.detailIndent)
                    .padding(.bottom, Self.rowSpacing)
            }
        }
    }

    /// One row open at a time: opening another closes the last.
    private func toggle(_ item: AgendaItem) {
        expanded = expanded == item.id ? nil : item.id
    }

    private func showSettings() {
        NSApplication.shared.activate()
        openSettings()
    }
}
