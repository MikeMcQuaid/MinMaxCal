import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

@Test
func `an expiring takeover cannot hide the next event at its start`() throws {
    let presenter = FakePresenter()
    let model = try TakeoverModel(
        source: FakeCalendarSource(),
        opener: FakeLinkOpener(),
        ledger: Fixtures.ledgerStore(),
        settings: Fixtures.settingsStore(),
        presenter: presenter,
        clock: Fixtures.clock,
    )
    var previous = Fixtures.event("previous", startingIn: -1)
    previous.end = Fixtures.now.addingTimeInterval(60)
    let next = Fixtures.event("next", startingIn: 1)
    let horizon = DateInterval(start: Fixtures.now, duration: 86_400)
    let previousTakeover = Takeover(entries: [.init(item: previous, trigger: .start)], moment: previous.start)
    model.present(previousTakeover)
    model.schedule(agenda: Agenda(items: [previous, next], horizon: horizon), now: Fixtures.now)
    #expect(model.planned == previousTakeover)

    let due = Agenda(items: [next], horizon: horizon)
    model.tick(agenda: due, now: next.start)
    #expect(model.current?.primary?.item.id == next.id)
    #expect(presenter.shown == 2)
    model.tick(agenda: due, now: next.start.addingTimeInterval(60))
    #expect(presenter.shown == 2)
}
