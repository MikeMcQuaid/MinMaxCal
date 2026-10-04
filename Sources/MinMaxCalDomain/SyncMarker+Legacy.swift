import Foundation

public extension SyncMarker {
    /// Reads the embedded original UID from the legacy Google IDs observed during migration.
    static func legacySourceIdentifier(in identifier: String?) -> String? {
        let domain = "@google.com"
        let prefix = "reclaim-personal-sync:_"
        guard let identifier, identifier.hasSuffix(domain),
              let tracking = decodeBase32Hex(identifier.dropLast(domain.count)), tracking.hasPrefix(prefix)
        else {
            return nil
        }

        return decodeBase32Hex(tracking.dropFirst(prefix.count))
    }

    private static let base32HexAlphabet: Array = .init("0123456789abcdefghijklmnopqrstuv".utf8)

    private static func decodeBase32Hex(_ encoded: Substring) -> String? {
        guard encoded.isEmpty == false else {
            return nil
        }

        // swiftlint:disable no_magic_numbers - Base32hex packs five-bit symbols into eight-bit bytes.
        var buffer: UInt16 = 0
        var bits = 0
        var bytes = [UInt8]()
        for character in encoded.lowercased().utf8 {
            guard let value = base32HexAlphabet.firstIndex(of: character) else {
                return nil
            }

            buffer = (buffer << 5) | UInt16(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8(buffer >> bits))
                buffer &= (1 << bits) - 1
            }
        }
        guard bits < 5, buffer == 0 else {
            return nil
        }

        // swiftlint:enable no_magic_numbers

        return String(bytes: bytes, encoding: .utf8)
    }
}
