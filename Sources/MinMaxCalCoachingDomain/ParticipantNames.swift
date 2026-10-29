import Foundation

/// Editable name suggestions from invitation text, never voice identities.
public enum ParticipantNames {
    // MARK: Public

    /// Turns an email address into an editable display name.
    public static func displayName(_ rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.contains("@"), let local = value.split(separator: "@").first else {
            return value
        }

        return String(local)
            .components(separatedBy: CharacterSet(charactersIn: "._+"))
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .capitalized
    }

    /// Suggests the other person only when the title and invitees agree.
    public static func otherPerson(
        title: String,
        myName ownName: String,
        invitees: [String],
    ) -> String? {
        let myName = displayName(ownName)
        guard myName.isEmpty == false else {
            return nil
        }

        let others =
            Array(Set(invitees.map(displayName).filter { $0.isEmpty == false && matches($0, myName) == false }))
        guard others.count <= 1 else {
            return nil
        }

        let titleNames = title.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
        if titleNames.count == 2, titleNames.count(where: { matches($0, myName) }) == 1,
           let other = titleNames.first(where: { $0.isEmpty == false && matches($0, myName) == false }),
           others.isEmpty || matches(other, others[0])
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            return other
        }
        return others.first
    }

    // MARK: Private

    private static func matches(
        _ firstName: String,
        _ secondName: String,
    ) -> Bool {
        let first = firstName.lowercased().split(separator: " ")
        let second = secondName.lowercased().split(separator: " ")
        return first == second || ((first.count == 1 || second.count == 1) && first.first == second.first)
    }
}
