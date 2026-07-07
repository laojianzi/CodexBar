import SwiftUI

@MainActor
struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .background(HiddenWindowConfigurator().allowsHitTesting(false))
            .onReceive(NotificationCenter.default.publisher(for: .codexbarOpenSettings)) { _ in
                Task { @MainActor in
                    NSApp.activate(ignoringOtherApps: true)
                    _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
            .task {
                // Migrate keychain items to reduce permission prompts during development (runs off main thread)
                await Task.detached(priority: .userInitiated) {
                    KeychainMigration.migrateIfNeeded()
                }.value
            }
    }

    static func configureKeepaliveWindow(_ window: NSWindow) {
        window.title = "CodexBarLifecycleKeepalive"
        window.identifier = NSUserInterfaceItemIdentifier("CodexBarLifecycleKeepalive")
        window.styleMask = [.borderless]
        window.collectionBehavior = [.ignoresCycle, .transient, .canJoinAllSpaces]
        window.isExcludedFromWindowsMenu = true
        window.level = .floating
        window.isOpaque = false
        window.alphaValue = 0
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.canHide = false
        window.isRestorable = false
        window.setFrame(NSRect(x: -5000, y: -5000, width: 1, height: 1), display: false)
    }
}

@MainActor
private struct HiddenWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> HiddenWindowConfiguratorView {
        HiddenWindowConfiguratorView()
    }

    func updateNSView(_ nsView: HiddenWindowConfiguratorView, context: Context) {
        nsView.configureWindow()
    }
}

@MainActor
private final class HiddenWindowConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.configureWindow()
    }

    func configureWindow() {
        guard let window else { return }
        HiddenWindowView.configureKeepaliveWindow(window)
    }
}
