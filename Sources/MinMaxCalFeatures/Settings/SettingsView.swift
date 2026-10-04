import SwiftUI

public struct SettingsView: View {
    // MARK: Lifecycle

    public init(model: SettingsModel) {
        self.model = model
    }

    // MARK: Public

    public var body: some View {
        TabView {
            Tab("Calendars", systemImage: "calendar") {
                CalendarsTab(model: model)
            }
            if let sync = model.sync {
                Tab("Sync", systemImage: "arrow.triangle.2.circlepath") {
                    CalendarSyncTab(model: sync, calendars: model.lists)
                }
            }
            Tab("Takeover", systemImage: "rectangle.inset.filled") {
                TakeoverTab(model: model)
            }
            Tab("Join", systemImage: "video") {
                JoinTab(model: model)
            }
            Tab("Matching", systemImage: "arrow.triangle.merge") {
                MatchingTab(model: model)
            }
            Tab("General", systemImage: "gearshape") {
                GeneralTab(model: model)
            }
            Tab("About", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(width: Self.width, height: Self.height)
        .task { await model.load() }
    }

    // MARK: Private

    private static let width: CGFloat = 520
    private static let height: CGFloat = 460

    private let model: SettingsModel
}
