import Foundation

/// The display name for an attendee EventKit only knows by address.
public enum AttendeeName {
    // MARK: Public

    /// The given name, or `Firstname Lastname` read from a `firstname.lastname@` address, or the address.
    public static func display(name: String?, email: String?) -> String {
        if let name, name.isEmpty == false, name != email {
            return name
        }
        guard let email else {
            return name ?? ""
        }

        let dottedName = /([A-Za-z][A-Za-z-]*)\.([A-Za-z][A-Za-z-]*)/
        guard let local = email.split(separator: "@").first, let match = local.wholeMatch(of: dottedName) else {
            return email
        }

        return "\(capitalised(String(match.output.1))) \(capitalised(String(match.output.2)))"
    }

    // MARK: Private

    /// `mcquaid` is `McQuaid` and `o-neil` is `O-Neil`; the rest is plain capitalisation.
    private static let scotsPrefix = "Mc"

    private static func capitalised(_ word: String) -> String {
        let plain = word.capitalized
        guard plain.hasPrefix(scotsPrefix), plain.count > scotsPrefix.count else {
            return plain
        }

        return scotsPrefix + plain.dropFirst(scotsPrefix.count).capitalized
    }
}
