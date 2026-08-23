import Foundation

/// The display name for an attendee EventKit only knows by address.
public enum AttendeeName {
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

        return "\(match.output.1.capitalized) \(match.output.2.capitalized)"
    }
}
