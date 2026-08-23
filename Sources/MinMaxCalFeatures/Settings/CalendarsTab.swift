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
                groups(model.calendarGroups)
                if model.calendarGroups.isEmpty == false, model.reminderGroups.isEmpty == false {
                    Divider()
                }
                groups(model.reminderGroups)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private static let groupSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let markSize: CGFloat = 13

    private func groups(_ groups: [AccountGroup]) -> some View {
        ForEach(groups) { group in
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                Text(group.account)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(group.lists) { list in
                    Toggle(isOn: model.isSelected(list)) {
                        HStack(spacing: 0) {
                            CalendarMarks(calendars: [list], size: Self.markSize, columnWidth: 0)
                            Text(list.title)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
}
