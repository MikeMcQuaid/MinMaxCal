import MinMaxCalDomain
import SwiftUI

struct CalendarsTab: View {
    // MARK: Internal

    let model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.groupSpacing) {
                Text("Tick the calendars and reminder lists to show. Nothing is selected until you choose.")
                    .foregroundStyle(.secondary)
                if model.lists.isEmpty {
                    Text("No calendars are available. Check the permissions in the General tab.")
                        .foregroundStyle(.secondary)
                }
                groups("Calendars", model.calendarGroups)
                groups("Reminders", model.reminderGroups)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private static let groupSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let markSize: CGFloat = 13
    private static let markSpacing: CGFloat = 3

    @ViewBuilder
    private func groups(_ title: String, _ groups: [AccountGroup]) -> some View {
        if groups.isEmpty == false {
            Text(title)
                .font(.headline)
        }
        ForEach(groups) { group in
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                Text(group.account)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(group.lists) { list in
                    Toggle(isOn: model.isSelected(list)) {
                        HStack(spacing: Self.markSpacing) {
                            CalendarMarks(calendars: [list], size: Self.markSize, columnWidth: 0)
                            Text(list.title)
                        }
                    }
                }
            }
        }
    }
}
