import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import SwiftUI
import Testing

struct SnapshotTests {
    // MARK: Internal

    @Test
    func `renders an agenda row`() throws {
        let link = try JoinLink(service: .zoom, url: #require(URL(string: "zoommtg://zoom.us/join?confno=1")))
        let row = AgendaRow(
            item: Fixtures.event("e", title: "Weekly planning", link: link),
            now: Fixtures.now,
            style: .agenda,
            onJoin: { _ in },
        )
        let image = try #require(render(row.frame(width: 360)))
        #expect(image.width == 360)
        #expect(image.height > 0)
    }

    @Test
    func `renders every takeover sample`() throws {
        let model = try TakeoverModel(
            source: FakeCalendarSource(),
            opener: FakeLinkOpener(),
            ledger: Fixtures.ledgerStore(),
            settings: Fixtures.settingsStore(),
            presenter: FakePresenter(),
            clock: Fixtures.clock,
        )
        for sample in AgendaItem.Sample.allCases {
            model.preview(sample)
            let image = try #require(render(TakeoverView(model: model).frame(width: 1_200, height: 900)))
            #expect(image.width == 1_200)
            model.dismiss()
        }
    }

    @Test
    func `renders the agenda`() async throws {
        let source = FakeCalendarSource()
        source.items = [Fixtures.event("e", title: "Weekly planning"), Fixtures.reminder("r", title: "Call back")]
        let model = try AgendaModel(
            source: source,
            settings: Fixtures.settingsStore(),
            opener: FakeLinkOpener(),
            clock: Fixtures.clock,
        )
        await model.rebuild()

        let image = try #require(render(AgendaView(model: model)))

        #expect(image.width == 360)
    }

    // MARK: Private

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }
}
