import Foundation

struct FakeError: Error, LocalizedError {
    var errorDescription: String? {
        "Could not save."
    }
}
