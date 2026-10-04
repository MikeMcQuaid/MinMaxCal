import MinMaxCalDomain
@testable import MinMaxCalFeatures
import SwiftUI
import Testing

struct SyncPolicyViewTests {
    @Test(arguments: [false, true], [false, true])
    func `disabled and unavailable pairs can change calendars with managed copies`(
        enabled: Bool, available: Bool,
    ) {
        var policy = Fixtures.syncPolicy
        policy.isEnabled = enabled
        let view = SyncPolicyView(
            policy: .constant(policy),
            calendars: available ? Fixtures.syncCalendars : [],
            hasCopies: true,
            canRemoveCopies: false,
            previewRemoval: { [] },
            removeCopies: { _ in },
            removeRule: {},
        )
        #expect(view.canEditCalendars == (enabled == false || available == false))
    }
}
