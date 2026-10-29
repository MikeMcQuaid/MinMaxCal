import Foundation
import MinMaxCalCoachingDomain

public actor JSONMeetingStore: MeetingStore {
    // MARK: Lifecycle

    @preconcurrency
    public init(
        directory: URL = URL.applicationSupportDirectory.appending(path: "MinMaxCal/Meetings"),
        clock: @escaping @Sendable () -> Date = { Date() },
    ) {
        self.directory = directory
        self.clock = clock
    }

    // MARK: Public

    public func load(
        meetingRetention: MeetingRetention = .twoDays,
        preserving activeID: UUID? = nil,
    ) throws -> [Meeting] {
        retention = meetingRetention
        let now = clock()
        let meetings = try (cached ?? read()).filter { meeting in
            if meeting.id != activeID, meeting.hasExpired(retention: retention, at: now) {
                try delete(id: meeting.id)
                return false
            }
            return true
        }
        cached = meetings
        return meetings.sorted { $0.startedAt > $1.startedAt }
    }

    public func save(_ meeting: Meeting) throws {
        if meeting.endedAt != nil || meeting.isComplete || meeting.notice != nil,
           meeting.hasExpired(retention: retention, at: clock())
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            try delete(id: meeting.id)
            return
        }

        try write(meeting)
        cached?.removeAll { $0.id == meeting.id }
        cached?.append(meeting)
    }

    public func delete(id: UUID) throws {
        let file = directory.appending(path: "\(id).json")
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: file)
        }
        cached?.removeAll { $0.id == id }
    }

    // MARK: Private

    private let directory: URL
    private let clock: @Sendable () -> Date
    // swiftlint:disable:next discouraged_optional_collection - Nil marks history not yet read from disk.
    private var cached: [Meeting]?
    private var retention: MeetingRetention = .twoDays

    private func write(_ meeting: Meeting) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(meeting).write(to: directory.appending(path: "\(meeting.id).json"), options: .atomic)
    }

    private func read() throws -> [Meeting] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(Meeting.self, from: Data(contentsOf: $0)) }
    }
}
