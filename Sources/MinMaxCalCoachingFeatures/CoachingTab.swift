import SwiftUI

public struct CoachingTab: View {
    // MARK: Lifecycle

    public init(controller: CoachingController) {
        self.controller = controller
    }

    // MARK: Public

    public var body: some View {
        // swiftlint:disable:next closure_body_length - One settings form.
        Form {
            Toggle("Enable meeting coaching", isOn: Binding(
                get: { controller.enabled },
                set: { value in Task {
                    await controller.setEnabled(value)
                }
                },
            ))
            .disabled(controller.isChanging)
            Text("Recording always needs an explicit Start or Record choice.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let model = controller.model {
                Section("Recording") {
                    Toggle("Record when joining", isOn: $controller.recordOnJoin)
                        .help("Applies to future joins. End Meeting stops the current recording.")
                }
                .disabled(controller.isChanging)
                Section("Speech models") {
                    switch model.modelState {
                    case .checking:
                        ProgressView("Checking saved models…")

                    case .downloading:
                        ProgressView(model.downloadStatus)
                        Button("Cancel Download", action: model.cancelModelDownload)

                    case .ready:
                        Label("Speech models ready", systemImage: "checkmark.circle")

                    case .missing:
                        Button("Download Speech Models", action: model.downloadSpeechModels)
                    }
                    Text("Saved models are reused across launches and rebuilds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                    }
                }
                .disabled(model.phase != .idle || controller.isChanging)
                CoachingSettingsView(model: model).disabled(controller.isChanging)
            }
        }
        .formStyle(.grouped)
        .buttonStyle(.glass)
    }

    // MARK: Private

    @Bindable private var controller: CoachingController
}
