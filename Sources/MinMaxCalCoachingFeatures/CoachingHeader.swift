import SwiftUI

public struct CoachingHeader: View {
    // MARK: Lifecycle

    public init(controller: CoachingController) {
        self.controller = controller
    }

    // MARK: Public

    public var body: some View {
        HStack {
            if let remaining = controller.model?.recordingTimeRemaining {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Recording")
                Text("Speaker reset in \(durationText(remaining.rounded(.up)))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .help(
                        """
                        Recording continues. Other speakers get fresh labels each hour; earlier names and words \
                        stay intact.
                        """
                    )
            }
            Spacer()
            Picker("View", selection: $controller.showingMeeting) {
                Text("Events").tag(false)
                Text("Record").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
        .disabled(controller.isChanging)
    }

    // MARK: Private

    @Bindable private var controller: CoachingController
}
