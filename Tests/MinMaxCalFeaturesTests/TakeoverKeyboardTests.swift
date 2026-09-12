import AppKit
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import SwiftUI
import Testing

@Suite(.serialized)
struct TakeoverKeyboardTests {
    // MARK: Lifecycle

    init() throws {
        settings = try Fixtures.settingsStore()
        settings.takeover.sound = nil
        model = TakeoverModel(
            source: source,
            opener: opener,
            ledger: ledger,
            settings: settings,
            presenter: presenter,
            clock: Fixtures.clock,
        )
        presenter.content = { [model] in AnyView(TakeoverView(model: model)) }
    }

    // MARK: Internal

    @Test(arguments: [AgendaItem.Sample.zoomEvent, .reminder], [[], [15, 5, 60]])
    func `keyboard actions work without a click`(sample: AgendaItem.Sample, snoozeMinutes: [Int]) async throws {
        settings.takeover.snoozeMinutes = snoozeMinutes
        try await pressKey(sample: sample, escape: false)
        try await pressKey(sample: sample, escape: true)
    }

    // MARK: Private

    private let presenter: TakeoverWindowController = .init { AnyView(EmptyView()) }
    private let source: FakeCalendarSource = .init()
    private let opener: FakeLinkOpener = .init()
    private let ledger: TakeoverLedgerStore = Fixtures.ledgerStore()
    private let settings: SettingsStore
    private let model: TakeoverModel

    private func pressKey(sample: AgendaItem.Sample, escape: Bool) async throws {
        let item = sample.item(now: Fixtures.now)
        let existing = NSApplication.shared.windows
        model.present(Takeover(
            entries: [Takeover.Entry(item: item, trigger: item.kind == .reminder ? .due : .start)],
            moment: item.start,
        ))
        defer { presenter.hide(returningFocus: true) }
        let window = try #require(NSApplication.shared
            .windows
            .first { $0 is TakeoverWindow && existing.contains($0) == false })
        #expect(window.firstResponder === window.contentView)
        window.contentView?.layoutSubtreeIfNeeded()
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: escape ? "\u{1B}" : "\r",
            charactersIgnoringModifiers: escape ? "\u{1B}" : "\r",
            isARepeat: false,
            keyCode: escape ? 53 : 36,
        ))

        if window.performKeyEquivalent(with: event) == false {
            window.sendEvent(event)
        }
        for _ in 0 ..< 100 where model.current != nil {
            await Task.yield()
        }

        #expect(model.current == nil)
        if escape {
            #expect(ledger.load().snoozeTime(for: item) == (
                item.kind == .reminder && settings.takeover.snoozeMinutes.isEmpty == false
                    ? Fixtures.now.addingTimeInterval(5 * 60) : nil
            ))
        } else if let link = item.joinLink {
            #expect(opener.opened == [link])
        } else {
            #expect(source.completed == item.members)
        }
    }
}
