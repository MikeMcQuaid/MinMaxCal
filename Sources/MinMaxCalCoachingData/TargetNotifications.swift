import MinMaxCalCoachingDomain
import UserNotifications

@preconcurrency
@MainActor
public final class TargetNotifications: NSObject, MeetingNotifier, UNUserNotificationCenterDelegate {
    // MARK: Lifecycle

    override public init() {
        super.init()
        center.delegate = self
    }

    // MARK: Public

    public var onMeetingResponse: (@MainActor (String, Bool) async -> Void)?

    public func requestAuthorization() async throws -> Bool {
        await registerCategories()
        return try await center.requestAuthorization(options: [.alert])
    }

    public func notify(_ message: String) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Make room for others"
        content.body = message
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        try await center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil,
        ))
    }

    public func clear() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    public func updateMeetingPrompts(
        _ candidates: [CalendarMeeting],
        at date: Date,
    ) async throws {
        let previous = schedulingTask
        // swiftlint:disable:next closure_body_length - One migrated audio operation.
        let task = Task {
            _ = try? await previous?.value
            if candidates.isEmpty == false {
                await registerCategories()
            }
            let settings = await center.notificationSettings()
            let meetings = settings.authorizationStatus == .authorized ? candidates : []
            let requests = Self.meetingRequests(
                for: meetings,
                at: date,
            )
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending
                .filter { pending in
                    pending.identifier.hasPrefix("coaching/calendar/") && requests
                        .contains(where: { $0.identifier == pending.identifier }) == false
                }
                .map(\.identifier))
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.compactMap { notification in
                let request = notification.request
                return request.identifier.hasPrefix("coaching/calendar/") && meetings
                    .contains(where: { "coaching/calendar/" + $0.id == request.identifier }) == false
                    ? request.identifier : nil
            })
            for request in requests {
                if let existing = pending.first(where: { $0.identifier == request.identifier }),
                   existing.content.isEqual(request.content),
                   (existing.trigger as? UNCalendarNotificationTrigger)?.dateComponents
                   == (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents
                // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                {
                    continue
                }
                try await center.add(request)
            }
        }
        schedulingTask = task
        try await task.value
    }

    nonisolated public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        guard response.notification.request.content.categoryIdentifier == "coaching-meeting",
              let id = response.notification.request.content.userInfo["meetingID"] as? String,
              ["record-meeting", UNNotificationDefaultActionIdentifier].contains(response.actionIdentifier)
        else {
            return
        }

        await onMeetingResponse?(id, response.actionIdentifier == "record-meeting")
    }

    @preconcurrency
    nonisolated public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completion: @Sendable (UNNotificationPresentationOptions) -> Void,
    ) {
        completion(notification.request.identifier.hasPrefix("coaching/") ? [.banner] : [.banner, .sound, .badge])
    }

    // MARK: Internal

    static func categories(merging categories: Set<UNNotificationCategory>) -> Set<UNNotificationCategory> {
        categories.filter { $0.identifier != "coaching-meeting" }.union([
            UNNotificationCategory(
                identifier: "coaching-meeting",
                actions: [
                    UNNotificationAction(identifier: "record-meeting", title: "Record", options: [.foreground]),
                    UNNotificationAction(identifier: "skip-meeting", title: "Not Now", options: []),
                ],
                intentIdentifiers: [],
                options: [],
            ),
        ]) // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
    }

    static func meetingRequests(
        for meetings: [CalendarMeeting],
        at date: Date,
    ) -> [UNNotificationRequest] {
        CalendarMeeting.inferred(
            from: meetings,
            at: date,
        )
        .filter { $0.canPrompt && $0.start > date }
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        .prefix(60)
        .map { meeting in
            let content = UNMutableNotificationContent()
            content.title = "Record this meeting?"
            content.subtitle = meeting.title
            content.body = "Starting now. Choose Record to capture this meeting, or Not Now to skip."
            content.categoryIdentifier = "coaching-meeting"
            content.userInfo = ["meetingID": meeting.id]
            return UNNotificationRequest(
                identifier: "coaching/calendar/" + meeting.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                        from: meeting.start,
                    ),
                    repeats: false,
                ),
            )
        }
    }

    // MARK: Private

    private let center: UNUserNotificationCenter = .current()
    private let identifier = "coaching/speaking-target"
    private var schedulingTask: Task<
        Void,
        any Error,
    >?

    private func registerCategories() async {
        await center.setNotificationCategories(Self.categories(merging: center.notificationCategories()))
    }
}
