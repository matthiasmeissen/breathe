import AppKit
import SwiftUI

/// Borderless window that covers the whole screen and sits above everything,
/// including full-screen apps. Esc or a click dismisses it.
final class OverlayWindow: NSWindow {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onDismiss?() } else { super.keyDown(with: event) }   // 53 = Esc
    }

    override func mouseDown(with event: NSEvent) { onDismiss?() }
}

@MainActor
final class OverlayController {
    private let settings: Settings
    private let breath = BreathClock()

    private var window: OverlayWindow?
    private var showTimer: Timer?
    private var hideTimer: Timer?
    private var previousApp: NSRunningApplication?

    init(settings: Settings) { self.settings = settings }

    // MARK: - Hook events

    func handle(_ event: HookServer.Event) {
        switch event {
        case .working:
            // Only show if Claude is still busy after the configured delay,
            // so a 3-second turn never flashes an overlay at you.
            // A new prompt while the overlay is fading out after Stop: keep it up instead.
            if window != nil { hideTimer?.invalidate(); hideTimer = nil; return }
            guard showTimer == nil else { return }
            showTimer = Timer.scheduledTimer(withTimeInterval: settings.showDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.showNow() }
            }

        case .idle:
            cancelShow()
            hideAfterCurrentBreath()

        case .attention:
            // Claude is waiting on you (permission prompt) – get out of the way right now.
            cancelShow()
            hide(fade: 0.25)
        }
    }

    // MARK: - Show / hide

    func showNow() {
        cancelShow()
        hideTimer?.invalidate(); hideTimer = nil
        guard window == nil, let screen = NSScreen.main else { return }

        previousApp = NSWorkspace.shared.frontmostApplication
        breath.restart()

        let w = OverlayWindow(contentRect: screen.frame,
                              styleMask: .borderless,
                              backing: .buffered,
                              defer: false)
        w.level = .screenSaver
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.contentView = NSHostingView(rootView: BreathingView(clock: breath))
        w.onDismiss = { [weak self] in self?.hide(fade: 0.2) }
        w.alphaValue = 0

        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)   // needed so Esc reaches the window

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            w.animator().alphaValue = 1
        }
    }

    private func hideAfterCurrentBreath() {
        guard window != nil, hideTimer == nil else { return }
        let wait = breath.timeUntilCycleEnd()
        hideTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.hide(fade: 1.0) }
        }
    }

    private func hide(fade: TimeInterval) {
        hideTimer?.invalidate(); hideTimer = nil
        guard let w = window else { return }
        window = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = fade
            w.animator().alphaValue = 0
        }, completionHandler: {
            w.orderOut(nil)
            // Hand focus back to whatever you were in (usually VS Code).
            self.previousApp?.activate()
            self.previousApp = nil
        })
    }

    private func cancelShow() {
        showTimer?.invalidate()
        showTimer = nil
    }
}
