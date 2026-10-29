import MinMaxCalDomain

public extension TakeoverModel {
    /// Offers the same recording controls in live and preview event takeovers.
    func offersRecording(for item: AgendaItem) -> Bool {
        current != nil && item.kind == .event && item.joinLink != nil && recordingEnabled()
    }

    /// Joins once and starts recording for a live takeover.
    func joinAndRecord(_ item: AgendaItem) {
        guard let takeover = current,
              let selected = takeover.entries.first(where: { $0.item.id == item.id })?.item,
              offersRecording(for: selected), recordingReady(), let link = selected.joinLink
        else {
            return
        }

        join(link)
        if takeover.isPreview == false {
            onRecord(selected)
        }
    }
}
