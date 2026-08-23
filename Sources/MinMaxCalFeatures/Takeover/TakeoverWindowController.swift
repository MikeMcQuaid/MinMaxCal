import AppKit
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

    // MARK: Public

    public var content: () -> AnyView

    public func show() {
        NSApplication.shared.activate()
        fit()
    }

    public func hide() {
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
    }

    // MARK: Private

    private var windows: [TakeoverWindow] = []

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
    }

    private func makeWindow(on screen: NSScreen) -> TakeoverWindow {
        let window = TakeoverWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen,
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content())
        return window
    }
}
