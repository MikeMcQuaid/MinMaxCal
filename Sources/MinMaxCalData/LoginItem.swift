public protocol LoginItem: Sendable {
    var status: LoginItemStatus { get }
    var isInstalledCopy: Bool { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}
