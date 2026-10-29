import Foundation
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `disabled coaching creates no services or background tasks`() async throws {
    let suite = "MinMaxCalCoaching-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    var creations = 0
    let controller = CoachingController(
        defaults: defaults,
        makeModel: {
            creations += 1
            return MeetingModel(
                recorder: Recorder(),
                store: Store(),
                speechModels: Models(),
            )
        },
    )
    controller.agendaChanged(at: .now)
    controller.tick(at: .now)
    await Task.yield()
    #expect(controller.enabled == false)
    #expect(controller.model == nil)
    #expect(creations == 0)
    await controller.setEnabled(true)
    #expect(creations == 1)
    #expect(controller.enabled)
    await controller.setEnabled(false)
    #expect(controller.model == nil)
    #expect(defaults.bool(forKey: "coaching.enabled") == false)
}

@Test
func `enabling checks saved models and missing models require an explicit download`() async throws {
    let suite = "MinMaxCalCoaching-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let recorder = Recorder()
    let models = Models(ready: false)
    let notifier = Notifier()
    let store = Store()
    let controller = CoachingController(
        defaults: defaults,
        makeModel: {
            MeetingModel(
                recorder: recorder,
                store: store,
                speechModels: models,
                notifier: notifier,
            )
        },
    )
    await controller.setEnabled(true)
    let model = try #require(controller.model)
    try await waitFor { model.modelState == .missing }
    #expect(await models.checks == 1)
    #expect(await models.downloads == 0)
    #expect(notifier.requests == 0)
    #expect(recorder.continuation == nil)
    model.start()
    #expect(model.phase == .idle)
    model.downloadSpeechModels()
    try await waitFor { model.modelState == .ready }
    #expect(await models.checks == 2)
    #expect(await models.downloads == 1)
    #expect(notifier.requests == 0)
    model.start()
    try await waitFor { model.phase == .recording }
    await controller.setEnabled(false)
    #expect(controller.model == nil)
    #expect(model.phase == .idle)
    #expect(model.canStart == false)
    #expect(notifier.scheduled.isEmpty)
    #expect(await store.load().count == 1)
    model.start()
    #expect(model.phase == .idle)
}
