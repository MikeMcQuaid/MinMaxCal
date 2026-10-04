import Foundation
import MinMaxCalDomain

struct SyncDiagnostics: Encodable {
    struct Rehearsal: Encodable {
        let checked: Int
        let failures: [String: String]
    }

    let schemaVersion = 1
    let dateEncoding = "secondsSince1970"
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    let operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
    let exportedAt: Date
    let timeZone: String
    let configuration: SyncSettings
    let ownership: [SyncLink]
    let lastChecked: Date?
    let snapshot: SyncDiagnosticSnapshot?
    let rehearsal: Rehearsal?
    let error: String?
}
