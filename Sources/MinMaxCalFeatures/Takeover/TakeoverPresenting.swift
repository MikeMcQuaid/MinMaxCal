public protocol TakeoverPresenting: AnyObject {
    /// Shows the panel on every display and reads `announcement` out to VoiceOver.
    func show(announcing announcement: String)
    /// Hides the panel; `returningFocus` hands activation back to the app that had it, which
    /// Join leaves to the call's own app.
    func hide(returningFocus: Bool)
}
