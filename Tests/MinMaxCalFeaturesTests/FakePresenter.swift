@testable import MinMaxCalFeatures

final class FakePresenter: TakeoverPresenting {
    var announcements: [String] = []
    var focusReturns: [Bool] = []

    var shown: Int {
        announcements.count
    }

    var hidden: Int {
        focusReturns.count
    }

    func show(announcing announcement: String) {
        announcements.append(announcement)
    }

    func hide(returningFocus: Bool) {
        focusReturns.append(returningFocus)
    }
}
