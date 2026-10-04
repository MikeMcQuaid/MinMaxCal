import MinMaxCalDomain
import SwiftUI

struct SyncPolicyView: View {
    // MARK: Internal

    @Binding var policy: SyncPolicy

    let calendars: [CalendarList]
    let hasCopies: Bool
    let canRemoveCopies: Bool
    let previewRemoval: () async throws -> [SyncWrite]
    let removeCopies: ([SyncWrite]) -> Void
    let removeRule: () -> Void

    var canEditCalendars: Bool {
        hasCopies == false || policy.isEnabled == false || policy.hasAvailableCalendars(in: calendars) == false
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                controls
                actions
                help
                if let removalError {
                    Text(removalError).foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Remove \(String(removals.count)) \(removals.count == 1 ? "copy" : "copies")?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible,
        ) {
            Button("Remove Copies", role: .destructive) { removeCopies(removals) }
        } message: {
            Text(
                "This disables the pair and removes these copies from the next month. Originals and later copies stay."
            )
        }
    }

    // MARK: Private

    @State private var confirmingRemoval = false
    @State private var removals: [SyncWrite] = []
    @State private var removalError: String?

    private var controls: some View {
        VStack(alignment: .leading) {
            Toggle("Enable this pair", isOn: $policy.isEnabled)
            calendarPicker("From", selection: $policy.source, writable: false)
            calendarPicker("To", selection: $policy.destination, writable: true)
            Picker("Copied content", selection: $policy.content) {
                Text("Busy").tag(SyncPolicy.Content.busy)
                Text("Travel").tag(SyncPolicy.Content.travel)
                Text("Original title, location and links").tag(SyncPolicy.Content.original)
            }
            Toggle("Only copy Busy events", isOn: $policy.onlyBusy)
            Picker("All-day events", selection: $policy.allDay) {
                Text("Don’t Copy").tag(SyncPolicy.AllDay.exclude)
                Text("Only Busy").tag(SyncPolicy.AllDay.busy)
                Text("Copy All").tag(SyncPolicy.AllDay.all)
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Remove Pair", systemImage: "trash", action: removeRule)
                .disabled(canEditCalendars == false)
                .help("Remove this rule and leave its existing calendar copies in place.")
            Spacer()
            Button("Remove Copies…") {
                Task {
                    do {
                        removals = try await previewRemoval()
                        removalError = nil
                        confirmingRemoval = true
                    } catch {
                        removalError = error.localizedDescription
                    }
                }
            }
            .disabled(hasCopies == false || canRemoveCopies == false)
            .help("Count this pair’s managed copies for review before removing them. Available in Sync mode.")
        }
        .buttonStyle(.glass)
    }

    private var help: some View {
        VStack(alignment: .leading) {
            Text(policy.hasAvailableCalendars(in: calendars)
                ? "Copies follow the From calendar. Editing a copy does not change its original."
                : "This pair cannot sync until both calendars are available and the destination is writable.")
            Text("Disable this pair to change its calendars or remove it. Existing copies stay in place.")
            Text("Busy and Travel hide the original details. Calendar sharing controls who sees copied fields.")
            Text("Missing availability counts as Busy. Events without your RSVP count as accepted.")
            Text(
                "Notes, attendees and alarms are never copied. Declined and unanswered invitations are skipped."
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func calendarPicker(_ title: String, selection: Binding<String>, writable: Bool) -> some View {
        let available = calendars.filter { calendar in
            calendar.kind == .event && (writable == false || (calendar.allowsChanges && calendar.supportsBusy))
        }
        return Picker(title, selection: Binding(
            get: { selection.wrappedValue },
            set: { value in
                policy.isEnabled = false
                selection.wrappedValue = value
            },
        )) {
            Text("Choose Calendar…").tag("")
            if selection.wrappedValue.isEmpty == false {
                if available.contains(where: { $0.identifier == selection.wrappedValue }) == false {
                    Text("Unavailable calendar").tag(selection.wrappedValue)
                }
            }
            ForEach(available) { calendar in
                Text("\(calendar.accountName) · \(calendar.title)").tag(calendar.identifier)
            }
        }
        .disabled(canEditCalendars == false)
    }
}
