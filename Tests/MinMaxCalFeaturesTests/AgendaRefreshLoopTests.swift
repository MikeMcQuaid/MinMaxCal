import Foundation
import MinMaxCalData
@testable import MinMaxCalFeatures
import Testing

struct AgendaRefreshLoopTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = AgendaModel(
            source: source,
            settings: store,
            opener: FakeLinkOpener(),
            systemChanges: systemChanges.stream,
            powerChanges: powerChanges.stream,
            clock: clock.read,
        )
    }

    // MARK: Internal

    @Test
    func `calendar and system changes still fetch immediately on battery`() async throws {
        powerChanges.continuation.yield(true)
        let loop = Task { await model.run() }
        defer { loop.cancel() }
        try await waitForFetches(1)

        source.items = [Fixtures.event("new")]
        source.notifyChange()
        try await waitForFetches(2)
        #expect(model.agenda.items == source.items)

        source.items = []
        systemChanges.continuation.yield()
        try await waitForFetches(3)
        #expect(model.agenda.items.isEmpty)
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(15 * 60))

        loop.cancel()
        await loop.value
    }

    @Test
    func `switching to mains fetches when its shorter fallback is already due`() async throws {
        powerChanges.continuation.yield(true)
        let loop = Task { await model.run() }
        defer { loop.cancel() }
        try await waitForFetches(1)
        let deadline = ContinuousClock.now + .seconds(5)
        while model.nextTick != Fixtures.now.addingTimeInterval(15 * 60), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(15 * 60))

        clock.now = Fixtures.now.addingTimeInterval(6 * 60)
        source.items = [Fixtures.event("new")]
        powerChanges.continuation.yield(false)
        try await waitForFetches(2)
        #expect(model.agenda.items == source.items)
    }

    @Test
    func `a power update cannot overwrite a pending fetch request`() async throws {
        let loop = Task { await model.run() }
        defer { loop.cancel() }
        try await waitForFetches(1)

        source.items = [Fixtures.event("new")]
        model.requestRefresh()
        model.setPowerSaving(true)
        try await waitForFetches(2)

        #expect(model.agenda.items == source.items)
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let clock: AdjustableClock = .init()
    private let store: SettingsStore
    private let model: AgendaModel
    private let systemChanges: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation) =
        AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let powerChanges: (stream: AsyncStream<Bool>, continuation: AsyncStream<Bool>.Continuation) =
        AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))

    private func waitForFetches(_ count: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while source.fetches < count, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(source.fetches == count)
    }
}
