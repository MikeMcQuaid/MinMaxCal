import MinMaxCalDomain
import SwiftUI

public struct CalendarToggle: View {
    // MARK: Lifecycle

    public init(list: CalendarList, isOn: Binding<Bool>) {
        self.list = list
        _isOn = isOn
    }

    // MARK: Public

    public var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Self.markSpacing) {
                CalendarMarks(calendars: [list], size: Self.markSize, columnWidth: 0)
                Text(list.title)
            }
        }
    }

    // MARK: Private

    private static let markSize: CGFloat = 13
    private static let markSpacing: CGFloat = 3

    @Binding private var isOn: Bool

    private let list: CalendarList
}
