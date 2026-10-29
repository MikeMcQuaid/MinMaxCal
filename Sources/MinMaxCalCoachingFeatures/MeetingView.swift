import MinMaxCalAgenda
import MinMaxCalCoachingDomain
import MinMaxCalDomain
import SwiftUI

public struct MeetingView: View {
    // MARK: Lifecycle

    public init(
        model: MeetingModel,
        targetShare: Double,
        turnLimit: Double,
        joinLink: JoinLink? = nil,
        recordsMeeting: Bool = false,
        joinEnabled: Bool = true,
        onJoin: ((JoinLink) -> Void)? = nil,
    ) {
        self.model = model
        self.targetShare = targetShare
        self.turnLimit = turnLimit
        self.joinLink = joinLink
        self.onJoin = onJoin
        self.recordsMeeting = recordsMeeting
        self.joinEnabled = joinEnabled
    }

    // MARK: Public

    public var body: some View {
        // swiftlint:disable:next closure_body_length - One compact recording panel.
        ScrollViewReader { proxy in
            // swiftlint:disable:next closure_body_length - One compact recording panel.
            ScrollView {
                // swiftlint:disable:next closure_body_length no_magic_numbers - One panel, matching agenda spacing.
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Meeting coaching", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                        Spacer()
                        if let joinLink, let onJoin {
                            JoinButton(link: joinLink, isPrimary: false, recordsMeeting: recordsMeeting, action: onJoin)
                                .disabled(joinEnabled == false)
                        }
                    }
                    .id("top")
                    if let error = model.displayedError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                    if let meeting = model.current, model.phase != .idle {
                        MeetingTitleView(meeting: meeting)
                        MeetingDetailsView(
                            model: model,
                            meeting: meeting,
                            targetShare: targetShare,
                            turnLimit: turnLimit,
                        )
                        .id(meeting.id)
                        UpcomingMeetingsView(model: model)
                    } else {
                        MeetingSetupView(model: model)
                    }
                    if model.phase == .preparing || model.phase == .stopping {
                        ProgressView(model.phase == .preparing ? "Starting audio capture…" : "Finishing your summary…")
                    }
                    MeetingHistoryView(
                        model: model,
                        targetShare: targetShare,
                        turnLimit: turnLimit,
                        scroll: proxy,
                        isExpanded: $showingHistory,
                    )
                }
                // swiftlint:disable:next no_magic_numbers - Match the agenda panel padding.
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.phase, initial: true) {
                if model.phase == .idle, model.selected != nil {
                    showingHistory = true
                    proxy.scrollTo("history", anchor: .top)
                } else if model.phase == .preparing || model.phase == .recording {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            .onChange(of: showingHistory) {
                if showingHistory == false, model.phase == .idle {
                    model.selectedID = nil
                }
            }
        }
        .buttonStyle(.glass)
        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
        .frame(maxHeight: min(580, (NSScreen.main?.visibleFrame.height ?? 800) - 120))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Private

    @Bindable private var model: MeetingModel
    @State private var showingHistory = false

    private let targetShare: Double
    private let turnLimit: Double
    private let joinLink: JoinLink?
    private let onJoin: ((JoinLink) -> Void)?
    private let recordsMeeting: Bool
    private let joinEnabled: Bool
}
