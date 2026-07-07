import AppKit
import Combine
import CoreVideo
import QuartzCore

@available(macOS 14, *)
private final class NativeDisplayLinkBox {
    let displayLink: CADisplayLink

    init(_ displayLink: CADisplayLink) {
        self.displayLink = displayLink
    }
}

/// Minimal display link driver using NSScreen.displayLink on macOS 15+,
/// and CVDisplayLink on earlier systems.
/// Publishes ticks on the main thread at the requested frame rate.
@MainActor
final class DisplayLinkDriver: ObservableObject {
    // Published counter used to drive SwiftUI updates.
    @Published var tick: Int = 0
    private var nativeDisplayLinkBox: Any?
    private var cvDisplayLink: CVDisplayLink?
    private var targetInterval: CFTimeInterval = 1.0 / 60.0
    private var lastTickTimestamp: CFTimeInterval = 0
    private let onTick: (() -> Void)?

    init(onTick: (() -> Void)? = nil) {
        self.onTick = onTick
    }

    func start(fps: Double = 12) {
        guard self.nativeDisplayLinkBox == nil, self.cvDisplayLink == nil else { return }
        let clampedFps = max(fps, 1)
        self.targetInterval = 1.0 / clampedFps
        self.lastTickTimestamp = 0
        if #available(macOS 15, *), let screen = NSScreen.main {
            let displayLink = screen.displayLink(target: self, selector: #selector(self.step))
            let rate = Float(clampedFps)
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: rate,
                maximum: rate,
                preferred: rate)
            displayLink.add(to: .main, forMode: .common)
            self.nativeDisplayLinkBox = NativeDisplayLinkBox(displayLink)
        } else {
            self.startCVDisplayLink()
        }
    }

    func stop() {
        if #available(macOS 14, *), let box = self.nativeDisplayLinkBox as? NativeDisplayLinkBox {
            box.displayLink.invalidate()
        }
        self.nativeDisplayLinkBox = nil
        if let cvDisplayLink = self.cvDisplayLink {
            CVDisplayLinkStop(cvDisplayLink)
        }
        self.cvDisplayLink = nil
    }

    @objc private func step(_: AnyObject) {
        self.handleTick()
    }

    private func handleTick() {
        let now = CACurrentMediaTime()
        if self.lastTickTimestamp > 0, now - self.lastTickTimestamp < self.targetInterval {
            return
        }
        self.lastTickTimestamp = now
        // Safe on main runloop; drives SwiftUI updates.
        self.tick &+= 1
        self.onTick?()
    }

    private func startCVDisplayLink() {
        var link: CVDisplayLink?
        if CVDisplayLinkCreateWithActiveCGDisplays(&link) != kCVReturnSuccess {
            return
        }
        guard let link else { return }
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnSuccess }
            let driver = Unmanaged<DisplayLinkDriver>.fromOpaque(userInfo).takeUnretainedValue()
            driver.scheduleTick()
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
        self.cvDisplayLink = link
    }

    private nonisolated func scheduleTick() {
        Task { @MainActor [weak self] in
            self?.handleTick()
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
