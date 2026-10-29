import SwiftUI

public struct CoachingControls: View {
    // MARK: Lifecycle

    public init(controller: CoachingController) {
        self.controller = controller
    }

    // MARK: Public

    public var body: some View {
        if let model = controller.model {
            if controller.showingMeeting || model.phase != .idle {
                switch model.phase {
                case .recording:
                    Button("End Meeting", systemImage: "stop.fill") { Task {
                        await model.stop()
                    }
                    }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)

                case .preparing:
                    Button("Cancel") { Task {
                        await model.stop()
                    }
                    }

                case .stopping:
                    ProgressView().controlSize(.small)

                case .idle:
                    if model.canRestart {
                        Button("New Meeting", systemImage: "plus") { model.selectedID = nil }
                        Button("Restart Recording", systemImage: "arrow.clockwise", action: model.restart)
                            .buttonStyle(.glassProminent)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Start Meeting", systemImage: "record.circle", action: model.start)
                            .buttonStyle(.glassProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.canStart == false)
                    }
                }
            }
        }
    }

    // MARK: Private

    private let controller: CoachingController
}
