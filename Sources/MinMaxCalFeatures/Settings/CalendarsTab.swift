import MinMaxCalDomain
import SwiftUI

struct CalendarsTab: View {
    // MARK: Internal

    let model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.groupSpacing) {
                if model.lists.isEmpty {
                    Text("No calendars are available. Check the permissions in the General tab.")
                        .foregroundStyle(.secondary)
                }
                groups("Calendars", model.calendarGroups)
                groups("Reminder lists", model.reminderGroups)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private static let groupSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let dotSpacing: CGFloat = 6

    @ViewBuilder
    private func groups(_ title: String, _ groups: [AccountGroup]) -> some View {
        if groups.isEmpty == false {
            Text(title)
                .font(.headline)
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    Text(group.account)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(group.lists) { list in
                        Toggle(isOn: model.isSelected(list)) {
                            HStack(spacing: Self.dotSpacing) {
                                CalendarDots(calendars: [list])
                                Text(list.title)
                            }
                        }
                    }
                }
            }
        }
    }
}
