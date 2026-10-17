import MinMaxCalDomain
import SwiftUI

/// An expandable agenda row with the same interactions on Mac and iPhone.
public struct AgendaEntry: View {
    // MARK: Lifecycle

    public init(
        item: AgendaItem,
        model: AgendaModel,
        expanded: Binding<AgendaItem.ID?>,
        onJoin: ((JoinLink) -> Void)? = nil,
        onPreview: (() -> Void)? = nil,
    ) {
        self.item = item
        self.model = model
        _expanded = expanded
        self.onJoin = onJoin
        self.onPreview = onPreview
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            row
            if expanded == item.id {
                VStack(alignment: .leading, spacing: Self.spacing) {
                    Text(item.displayTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    ItemDetails(item: item, rules: model.rules)
                        .font(.callout)
                }
                .padding(.leading, Self.detailIndent)
                .padding(.bottom, Self.spacing)
            }
        }
    }

    // MARK: Private

    private static let spacing: CGFloat = 4
    private static let detailIndent: CGFloat = 20
    private static let focusRadius: CGFloat = 6

    @Binding private var expanded: AgendaItem.ID?
    @State private var hovered = false

    private let item: AgendaItem
    private let model: AgendaModel
    private let onJoin: ((JoinLink) -> Void)?
    private let onPreview: (() -> Void)?

    private var row: some View {
        AgendaRow(
            item: item,
            style: .agenda,
            onJoin: onJoin,
            onComplete: {
                Task {
                    await model.complete(item)
                }
            },
            onUncomplete: {
                Task {
                    await model.uncomplete(item)
                }
            },
        )
        .contentShape(AgendaRow.contentShapeKinds, RoundedRectangle(cornerRadius: Self.focusRadius))
        .background {
            RoundedRectangle(cornerRadius: Self.focusRadius)
                .fill(.quaternary)
                .opacity(hovered ? 1 : 0)
        }
        .onHover { hovered = $0 }
        .onTapGesture(perform: toggle)
        .focusable(interactions: .activate)
        .onKeyPress(keys: [.return, .space]) { _ in
            toggle()
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.displayTitle)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(expanded == item.id ? "Hides the details" : "Shows the details")
        .accessibilityAction { toggle() }
        .contextMenu {
            Button(expanded == item.id ? "Hide Details" : "Show Details", action: toggle)
            if let onPreview {
                Button("Preview Takeover", action: onPreview)
            }
        }
    }

    private func toggle() {
        expanded = expanded == item.id ? nil : item.id
    }
}
