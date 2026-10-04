import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct SyncReportDocument: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
    }

    let data: Data
}
