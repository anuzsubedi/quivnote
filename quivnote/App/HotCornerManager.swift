//
//  HotCornerManager.swift
//  quivnote
//

import AppKit

/// Reveals a small, non-activating launcher when the pointer dwells in the
/// configured screen corner. Clicking the launcher brings quivnote forward.
@MainActor
final class HotCornerManager {
    enum Corner: String, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var label: String {
            switch self {
            case .topLeft: "Top Left"
            case .topRight: "Top Right"
            case .bottomLeft: "Bottom Left"
            case .bottomRight: "Bottom Right"
            }
        }

        var symbolName: String {
            switch self {
            case .topLeft: "arrow.up.left"
            case .topRight: "arrow.up.right"
            case .bottomLeft: "arrow.down.left"
            case .bottomRight: "arrow.down.right"
            }
        }
    }

    private static let launcherSize: CGFloat = 46
    private static let cornerTolerance: CGFloat = 6
    private static let launcherTolerance: CGFloat = 8

    private var launcher: HotCornerPanel?
    private var pollTimer: DispatchSourceTimer?
    private var isPointerInActivationArea = false
    private var suppressUntilPointerLeaves = false
    private var dwellGeneration = 0
    private let onActivate: () -> Void

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
    }

    func tearDown() {
        pollTimer?.cancel()
        pollTimer = nil
        launcher?.orderOut(nil)
        launcher = nil
    }

    // MARK: - Pointer tracking

    /// A dispatch timer keeps tracking while quivnote is inactive. App-local
    /// mouse tracking stops as soon as another application becomes active.
    func startPolling() {
        guard pollTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        timer.resume()
        pollTimer = timer
    }

    private func poll() {
        let settings = GeneralSettings.shared
        guard settings.hotCornerEnabled else {
            resetActivationState()
            return
        }

        let location = NSEvent.mouseLocation
        let activationScreen = NSScreen.screens.first {
            corner(at: location, on: $0) == settings.hotCorner
        }
        let isOverLauncher = launcher.map {
            $0.frame.insetBy(dx: -Self.launcherTolerance, dy: -Self.launcherTolerance).contains(location)
        } ?? false
        let isInsideActivationArea = activationScreen != nil || isOverLauncher

        guard isInsideActivationArea else {
            resetActivationState()
            return
        }

        guard !suppressUntilPointerLeaves else { return }
        guard !isPointerInActivationArea else { return }

        isPointerInActivationArea = true
        if let activationScreen {
            revealLauncher(after: 0.18, on: activationScreen)
        }
    }

    private func resetActivationState() {
        guard isPointerInActivationArea || suppressUntilPointerLeaves || launcher != nil else { return }
        isPointerInActivationArea = false
        suppressUntilPointerLeaves = false
        dwellGeneration += 1
        hideLauncher()
    }

    private func corner(at point: NSPoint, on screen: NSScreen) -> Corner? {
        let frame = screen.frame
        let nearLeft = point.x >= frame.minX && point.x <= frame.minX + Self.cornerTolerance
        let nearRight = point.x <= frame.maxX && point.x >= frame.maxX - Self.cornerTolerance
        let nearTop = point.y <= frame.maxY && point.y >= frame.maxY - Self.cornerTolerance
        let nearBottom = point.y >= frame.minY && point.y <= frame.minY + Self.cornerTolerance

        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        return nil
    }

    // MARK: - Launcher window

    private func revealLauncher(after delay: TimeInterval, on screen: NSScreen) {
        hideLauncher()
        let generation = dwellGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self,
                      self.dwellGeneration == generation,
                      self.isPointerInActivationArea,
                      !self.suppressUntilPointerLeaves
                else { return }
                self.showLauncher(on: screen)
            }
        }
    }

    private func showLauncher(on screen: NSScreen) {
        let corner = GeneralSettings.shared.hotCorner
        let panel = HotCornerPanel(size: Self.launcherSize, corner: corner) { [weak self] in
            self?.activate()
        }
        panel.setFrameOrigin(origin(for: corner, on: screen, size: Self.launcherSize))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        launcher = panel

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func activate() {
        suppressUntilPointerLeaves = true
        dwellGeneration += 1
        hideLauncher()
        onActivate()
    }

    private func origin(for corner: Corner, on screen: NSScreen, size: CGFloat) -> NSPoint {
        let frame = screen.frame
        let x = corner == .topLeft || corner == .bottomLeft ? frame.minX : frame.maxX - size
        let y = corner == .topLeft || corner == .topRight ? frame.maxY - size : frame.minY
        return NSPoint(x: x, y: y)
    }

    private func hideLauncher() {
        launcher?.orderOut(nil)
        launcher = nil
    }
}

private final class HotCornerPanel: NSPanel {
    init(size: CGFloat, corner: HotCornerManager.Corner, onActivate: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        ignoresMouseEvents = false
        appearance = AppearanceSettings.shared.mode.nsAppearance
        contentView = HotCornerLauncherView(corner: corner, onActivate: onActivate)
    }
}

/// Draws a compact note launcher that grows naturally out of the selected edge.
private final class HotCornerLauncherView: NSView {
    private let corner: HotCornerManager.Corner
    private let onActivate: () -> Void
    private var isHovered = false

    init(corner: HotCornerManager.Corner, onActivate: @escaping () -> Void) {
        self.corner = corner
        self.onActivate = onActivate
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Open quivnote")
        setAccessibilityHelp("Brings quivnote to the front")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()

        let badgeRect = badgeFrame.insetBy(dx: isHovered ? 0 : 1, dy: isHovered ? 0 : 1)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 13, yRadius: 13)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 9
        shadow.shadowOffset = inwardShadowOffset
        shadow.set()
        let fill = isHovered
            ? QuivPalette.nsRaised.blended(withFraction: 0.08, of: QuivPalette.nsAccent) ?? QuivPalette.nsRaised
            : QuivPalette.nsRaised
        fill.setFill()
        badge.fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSShadow().set()
        QuivPalette.nsBorder.setStroke()
        badge.lineWidth = 0.75
        badge.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()

        drawSymbol(in: iconFrame)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        onActivate()
    }

    private var badgeFrame: NSRect {
        let badgeSize: CGFloat = 44
        let bleed: CGFloat = 8
        let x = corner == .topLeft || corner == .bottomLeft ? -bleed : bounds.maxX - badgeSize + bleed
        let y = corner == .bottomLeft || corner == .bottomRight ? -bleed : bounds.maxY - badgeSize + bleed
        return NSRect(x: x, y: y, width: badgeSize, height: badgeSize)
    }

    private var iconFrame: NSRect {
        let size: CGFloat = 16
        let visibleCenterX: CGFloat = corner == .topLeft || corner == .bottomLeft ? 18 : bounds.maxX - 18
        let visibleCenterY: CGFloat = corner == .bottomLeft || corner == .bottomRight ? 18 : bounds.maxY - 18
        return NSRect(x: visibleCenterX - size / 2, y: visibleCenterY - size / 2, width: size, height: size)
    }

    private var inwardShadowOffset: NSSize {
        let x: CGFloat = corner == .topLeft || corner == .bottomLeft ? 2 : -2
        let y: CGFloat = corner == .bottomLeft || corner == .bottomRight ? 2 : -2
        return NSSize(width: x, height: y)
    }

    private func drawSymbol(in rect: NSRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        guard let image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Open quivnote")?
            .withSymbolConfiguration(configuration)
        else { return }

        let tinted = image.copy() as! NSImage
        tinted.lockFocus()
        QuivPalette.nsAccent.set()
        NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: rect)
    }
}
