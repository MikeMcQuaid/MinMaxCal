import AppKit
import MinMaxCalDomain
import SwiftUI

public final class TakeoverWindowController: TakeoverPresenting {
    // MARK: Lifecycle

    public init(content: @escaping () -> AnyView) {
        self.content = content
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
    }

    deinit {
        // Selector observers have unregistered themselves on deallocation since macOS 10.11, but
        // being explicit costs nothing if this controller ever stops living for the app's lifetime.
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public

    public var content: () -> AnyView

    public func show(announcing announcement: String, playing sound: TakeoverSound?) {
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != .current {
            previousApp = frontmost
        }
        NSApplication.shared.activate()
        fit()
        sound?.play()
        AccessibilityNotification.Announcement(announcement).post()
    }

    public func hide(returningFocus: Bool) {
        let hidden = windows
        windows = []
        if returningFocus, let previousApp, previousApp.isTerminated == false {
            _ = previousApp.activate(from: .current, options: [])
        }
        previousApp = nil
        fade(hidden, to: 0) {
            for window in hidden {
                window.orderOut(nil)
            }
        }
    }

    // MARK: Private

    private static let fadeDuration: TimeInterval = 0.2

    private var windows: [TakeoverWindow] = []
    /// The app that was in front when the panel came up, to give the front back to on dismissal.
    private var previousApp: NSRunningApplication?

    @objc
    private func screensChanged() {
        if windows.isEmpty == false {
            fit()
        }
    }

    private func fit() {
        let screens = NSScreen.screens
        windows.removeAll { window in
            guard let screen = window.screen, screens.contains(screen) else {
                window.orderOut(nil)
                return true
            }

            window.setFrame(screen.frame, display: true)
            return false
        }
        for screen in screens where windows.contains(where: { $0.screen == screen }) == false {
            windows.append(makeWindow(on: screen))
        }
        for window in windows {
            window.orderFrontRegardless()
        }
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKeyAndOrderFront(nil)
        fade(windows, to: 1)
    }

    private func makeWindow(on screen: NSScreen) -> TakeoverWindow {
        // The frame is in global coordinates; passing `screen:` too would offset it by the
        // screen's origin, leaving every display but the first half covered.
        let window = TakeoverWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: content())
        return window
    }

    /// A short fade, or none when the user asked for reduced motion. The completion is main actor
    /// isolated so it may capture windows; AppKit's own handler type is merely `@Sendable`.
    private func fade(
        _ windows: [TakeoverWindow],
        to alpha: CGFloat,
        then completion: (@MainActor @Sendable () -> Void)? = nil,
    ) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : Self.fadeDuration
            for window in windows {
                window.animator().alphaValue = alpha
            }
        }, completionHandler: completion.map { completion in
            { @Sendable in MainActor.assumeIsolated { completion() } }
        })
    }
}
