import MinMaxCalDomain
@testable import MinMaxCalFeatures

final class FakePresenter: TakeoverPresenting {
    var announcements: [String] = []
    var sounds: [TakeoverSound?] = []
    var focusReturns: [Bool] = []

    var shown: Int {
        announcements.count
    }

    var hidden: Int {
        focusReturns.count
    }

    func show(announcing announcement: String, playing sound: TakeoverSound?) {
        announcements.append(announcement)
        sounds.append(sound)
    }

    func hide(returningFocus: Bool) {
        focusReturns.append(returningFocus)
    }
}
