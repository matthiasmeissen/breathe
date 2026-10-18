import SwiftUI

@main
struct BreatheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Claude Breathe", systemImage: "wind") {
            Toggle("Enabled", isOn: Bindable(delegate.settings).enabled)

            Picker("Show after", selection: Bindable(delegate.settings).showDelay) {
                Text("Immediately").tag(0.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
                Text("20 seconds").tag(20.0)
            }

            Divider()
            Button("Test overlay") { delegate.overlay.showNow() }
            Text("Listening on 127.0.0.1:\(String(delegate.settings.port))")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

@Observable
final class Settings {
    var enabled = true
    var showDelay: TimeInterval = 2
    let port: UInt16 = 4466
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = Settings()
    private(set) lazy var overlay = OverlayController(settings: settings)
    private let server = HookServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        server.onEvent = { [weak self] event in
            guard let self, self.settings.enabled else { return }
            self.overlay.handle(event)
        }
        do {
            try server.start(port: settings.port)
        } catch {
            NSLog("ClaudeBreathe: could not start hook server: \(error)")
        }
    }
}
