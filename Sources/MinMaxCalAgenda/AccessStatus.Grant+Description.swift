import MinMaxCalData

public extension AccessStatus.Grant {
    /// The permission label shared by both Settings interfaces.
    nonisolated var description: String {
        switch self {
        case .full:
            "Full access"

        case .denied:
            "Denied"

        case .restricted:
            "Restricted"

        case .writeOnly:
            "Add only"

        case .notDetermined:
            "Not asked yet"
        }
    }
}
