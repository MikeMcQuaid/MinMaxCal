import MinMaxCalDomain
import SwiftUI

struct SyncChangesView: View {
    // MARK: Internal

    let write: SyncWrite

    var body: some View {
        VStack(alignment: .leading) {
            switch write {
            case let .save(_, source, target, content):
                detail(content)
                if source.content.title != content.title {
                    Text("Original: \(source.content.title)")
                }
                if let target, target.content.start != content.start || target.content.end != content.end {
                    Text("Current copy:")
                    times(target.content)
                }

            case let .remove(_, target, _):
                detail(target.content)
            }
            ForEach(write.reasons, id: \.self) { reason in
                Text("Why: \(reason)").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    // MARK: Private

    private func detail(_ content: SyncContent) -> some View {
        VStack(alignment: .leading) {
            Text("\(write.action.rawValue): \(content.title)").fontWeight(.medium)
            times(content)
        }
    }

    private func times(_ content: SyncContent) -> some View {
        VStack(alignment: .leading) {
            Text(content.start, format: .dateTime.day().month().hour().minute())
            Text(content.end, format: .dateTime.day().month().hour().minute())
        }
    }
}
