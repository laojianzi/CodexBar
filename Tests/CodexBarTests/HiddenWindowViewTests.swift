import AppKit
import Testing
@testable import CodexBar

@MainActor
struct HiddenWindowViewTests {
    @Test
    func `keepalive window is hidden offscreen and non interactive`() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        defer { window.close() }

        HiddenWindowView.configureKeepaliveWindow(window)

        #expect(window.identifier?.rawValue == "CodexBarLifecycleKeepalive")
        #expect(window.styleMask == [.borderless])
        #expect(window.alphaValue == 0)
        #expect(window.ignoresMouseEvents)
        #expect(window.isRestorable == false)
        #expect(window.frame == NSRect(x: -5000, y: -5000, width: 1, height: 1))
    }
}
