import MinMaxCalCoachingDomain
import SwiftUI

// MARK: - CoachingView

struct CoachingView: View {
    let meeting: Meeting
    let targetShare: Double
    let turnLimit: Double

    var body: some View {
        let balance = ConversationBalance(
            meeting: meeting,
            targetShare: targetShare,
            turnLimit: turnLimit,
        )
        VStack(
            alignment: .leading,
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            spacing: 14,
        ) {
            Label(balance.cue, systemImage: balance.needsRoom ? "ear.badge.waveform" : "bubble.left.and.bubble.right")
                .font(.headline)
                .foregroundStyle(balance.needsRoom ? .orange : .teal)
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            HStack(spacing: 28) {
                MetricView(
                    title: "Your share · last 5 min",
                    value: balance.isReliable ? balance.recentShare
                        .formatted(.percent.precision(.fractionLength(0))) : "Unknown",
                )
                MetricView(
                    title: "Current turn",
                    value: balance.isReliable ? durationText(balance.currentTurn) : "Unknown",
                )
            }
            Text(
                """
                Target: \(targetShare.formatted(.percent.precision(.fractionLength(0)))) of speech · Pause cue after \
                \(Int(turnLimit))s
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .background(
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            (balance.needsRoom ? Color.orange : .teal).opacity(0.08),
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            in: .rect(cornerRadius: 14),
        )
    }
}

// MARK: - MetricView

func durationText(_ seconds: Double) -> String {
    let value = Int(max(0, seconds.isFinite ? seconds : 0))
    // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
    return value >= 60 ? "\(value / 60)m \(value % 60)s" : "\(value)s"
}

// MARK: - CoachingSettingsView
