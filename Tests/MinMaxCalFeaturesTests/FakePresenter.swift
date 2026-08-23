@testable import MinMaxCalFeatures

final class FakePresenter: TakeoverPresenting {
    var shown = 0
    var hidden = 0

    func show() {
        shown += 1
    }

    func hide() {
        hidden += 1
    }
}
