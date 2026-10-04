import SwiftUI

struct SyncExportButton: View {
    // MARK: Internal

    let model: CalendarSyncModel

    var body: some View {
        VStack(alignment: .leading) {
            Button("Export Report…", systemImage: "square.and.arrow.up") {
                do {
                    document = try SyncReportDocument(data: model.exportDiagnostics())
                    errorMessage = nil
                    isExporting = true
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.glass)
            .disabled(model.isRunning)
            .help("Save the current diagnostics as JSON, including event titles, notes, locations and links.")
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            item: document,
            contentTypes: [.json],
            defaultFilename: "MinMaxCal-Sync-Report.json",
            onCompletion: { result in
                if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                }
                document = nil
            },
            onCancellation: { document = nil },
        )
    }

    // MARK: Private

    @State private var document: SyncReportDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?
}
