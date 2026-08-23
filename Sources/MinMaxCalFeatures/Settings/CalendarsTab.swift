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
                ForEach(model.groups) { group in
                    VStack(alignment: .leading, spacing: Self.rowSpacing) {
                        Text(group.account)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(group.lists) { list in
                            Toggle(isOn: model.isSelected(list)) {
                                row(list)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Private

    private static let groupSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let markSpacing: CGFloat = 6
    private static let markSize: CGFloat = 13

    private func row(_ list: CalendarList) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.markSpacing) {
            CalendarMarks(calendars: [list], size: Self.markSize)
            Text(list.title)
                .fontWeight(.semibold)
            Text(list.summary)
                .foregroundStyle(.secondary)
        }
    }
}
