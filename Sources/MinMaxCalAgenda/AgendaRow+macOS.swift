#if os(macOS)
import SwiftUI

extension AgendaRow {
    static let contentShapeKinds: ContentShapeKinds = [.interaction, .focusEffect]
    static let agendaMarkSize: CGFloat = 13
    static let agendaMinimumHeight: CGFloat = 24
    static let agendaTimeStyle: Font.TextStyle = .body
    static let agendaTimeWidth: CGFloat = usesTwelveHourClock ? twelveHourTimeWidth : twentyFourHourTimeWidth

    private static let twelveHourTimeWidth: CGFloat = 62
    private static let twentyFourHourTimeWidth: CGFloat = 40
}
#endif
