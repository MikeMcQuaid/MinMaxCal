import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct TakeoverRecordingTests {
    // MARK: Lifecycle

    init() throws {
        model = try TakeoverModel(
            source: FakeCalendarSource(),
            opener: opener,
            ledger: ledger,
            settings: Fixtures.settingsStore(),
            presenter: presenter,
            clock: Fixtures.clock,
        )
    }

    // MARK: Internal

    @Test
    func `join and record is explicit and hands focus to the call once`() throws {
        let item = try event()
        var recorded = [AgendaItem]()
        model.recordingEnabled = { true }
        model.recordingReady = { true }
        model.onRecord = { recorded.append($0) }
        model.present(Takeover(entries: [.init(item: item, trigger: .start)], moment: item.start))
        #expect(model.offersRecording(for: item))
        #expect(recorded.isEmpty)

        model.joinAndRecord(item)
        model.joinAndRecord(item)

        #expect(recorded == [item])
        #expect(opener.opened == [item.joinLink].compactMap(\.self))
        #expect(presenter.focusReturns == [false])
        #expect(ledger.load().isDismissed(item, trigger: .start, moment: item.start))
    }

    @Test(arguments: [false, true])
    func `disabled recording never offers recording actions`(preview: Bool) throws {
        let item = try event()
        var recordings = 0
        model.recordingEnabled = { false }
        model.recordingReady = { true }
        model.onRecord = { _ in recordings += 1 }
        model.present(Takeover(entries: [.init(item: item, trigger: .start)], moment: item.start, isPreview: preview))

        #expect(model.offersRecording(for: item) == false)
        model.joinAndRecord(item)
        #expect(recordings == 0)
        #expect(opener.opened.isEmpty)
    }

    @Test
    func `previews show recording actions without capturing audio`() throws {
        let item = try event()
        let link = try #require(item.joinLink)
        var recordings = 0
        model.recordingEnabled = { true }
        model.recordingReady = { true }
        model.onRecord = { _ in recordings += 1 }
        model.preview(item)

        #expect(model.offersRecording(for: item))
        #expect(recordings == 0)
        model.joinAndRecord(item)
        #expect(opener.opened == [link])
        #expect(recordings == 0)
        #expect(ledger.load() == .empty)
    }

    @Test
    func `missing models leave join without recording available`() throws {
        let item = try event()
        let link = try #require(item.joinLink)
        var recordings = 0
        model.recordingEnabled = { true }
        model.recordingReady = { false }
        model.onRecord = { _ in recordings += 1 }
        model.present(Takeover(entries: [.init(item: item, trigger: .start)], moment: item.start))

        model.joinAndRecord(item)
        #expect(model.current != nil)
        #expect(recordings == 0)
        #expect(opener.opened.isEmpty)
        model.join(link)
        #expect(recordings == 0)
        #expect(opener.opened == [link])
    }

    // MARK: Private

    private let opener: FakeLinkOpener = .init()
    private let presenter: FakePresenter = .init()
    private let ledger: TakeoverLedgerStore = Fixtures.ledgerStore()
    private let model: TakeoverModel

    private func event() throws -> AgendaItem {
        try Fixtures.event(
            "call",
            startingIn: 0,
            link: JoinLinkDetector.classify(#require(URL(string: "https://zoom.us/j/123456789"))),
        )
    }
}
