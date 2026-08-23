import MinMaxCalDomain
import SwiftUI

public struct TakeoverView: View {
    // MARK: Lifecycle

    public init(model: TakeoverModel) {
        self.model = model
    }

    // MARK: Public

    public var body: some View {
        ZStack {
            Color.black
                .opacity(Self.backdropOpacity)
                .ignoresSafeArea()
            if let takeover = model.current {
                panel(takeover)
            }
        }
    }

    // MARK: Private

    private static let panelWidth: CGFloat = 720
    private static let panelPadding: CGFloat = 32
    private static let cornerRadius: CGFloat = 28
    private static let backdropOpacity = 0.55
    private static let entrySpacing: CGFloat = 24

    private let model: TakeoverModel

    private func panel(_ takeover: Takeover) -> some View {
        let joinIsPrimary = takeover.primary?.item.joinLink != nil
        return VStack(alignment: .leading, spacing: Self.entrySpacing) {
            ForEach(Array(takeover.entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                }
                TakeoverEntryView(
                    entry: entry,
                    joinIsPrimary: joinIsPrimary && index == 0,
                    rules: model.rules,
                    onJoin: model.join,
                )
            }
            if let message = model.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
            }
            actions(takeover, completeIsPrimary: joinIsPrimary == false && takeover.primary?.item.kind == .reminder)
        }
        .padding(Self.panelPadding)
        .frame(width: Self.panelWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: Self.cornerRadius))
    }

    private func actions(_ takeover: Takeover, completeIsPrimary: Bool) -> some View {
        HStack {
            if takeover.reminders.isEmpty == false {
                CompleteButton(isPrimary: completeIsPrimary) {
                    Task { await model.complete() }
                }
                Menu("Snooze") {
                    ForEach(model.snoozeMinutes, id: \.self) { minutes in
                        Button("\(String(minutes)) minutes") {
                            model.snooze(minutes: minutes)
                        }
                    }
                }
                .fixedSize()
            }
            Spacer()
            Button("Dismiss", action: model.dismiss)
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
        }
    }
}
