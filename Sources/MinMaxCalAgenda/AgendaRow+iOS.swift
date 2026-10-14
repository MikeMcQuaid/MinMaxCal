#if os(iOS)
import SwiftUI

extension AgendaRow {
    static let contentShapeKinds: ContentShapeKinds = .interaction
    static let agendaMarkSize: CGFloat = 18
    static let agendaMinimumHeight: CGFloat = 44
    static let agendaTimeStyle: Font.TextStyle = .subheadline
    static let agendaTimeWidth: CGFloat = usesTwelveHourClock ? twelveHourTimeWidth : twentyFourHourTimeWidth

    private static let twelveHourTimeWidth: CGFloat = 75
    private static let twentyFourHourTimeWidth: CGFloat = 46
}
#endif
