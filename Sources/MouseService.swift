import AppKit
import ApplicationServices

final class MouseService {
    enum Sequence { case idle, tracking, passThrough, swallow }
    static let eventMarker: Int64 = 0x4D55415448
    var enabled = true
    var natural = false
    var reverseScroll = false
    var threshold = 55.0
    var excludedApps: Set<String> = []
    var onStatus: ((String) -> Void)?
    var onAction: ((String) -> Void)?
    var onMiddleClick: (() -> Void)?
    private(set) var running = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tracker = GestureTracker()
    private var sequence = Sequence.idle
    private var pendingDown: CGEvent?
    private var pendingDirection: GestureDirection?
    private var sendingShortcut = false

    func start() {
        guard !running else { return }
        guard AXIsProcessTrusted() else {
            onStatus?("Permission needed — open macOS permissions below")
            return
        }
        let mask = [CGEventType.otherMouseDown, .otherMouseDragged, .otherMouseUp, .mouseMoved, .scrollWheel]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MouseService>.fromOpaque(context).takeUnretainedValue()
                    .handle(proxy: proxy, type: type, event: event)
            }, userInfo: context
        ) else {
            onStatus?("Could not listen — check permission, then quit and reopen")
            return
        }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        running = true
        reportStatus()
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        // Pair a delivered down with the real up even if paused in the middle of a hold.
        if !value, sequence == .tracking {
            if tracker.didTrigger {
                sequence = .swallow
            } else {
                replayPendingDown()
                sequence = .passThrough
            }
            pendingDown = nil
            _ = tracker.end()
        }
        if value { start() }
        reportStatus()
    }

    func setReverseScroll(_ value: Bool) {
        reverseScroll = value
        if value { start() }
        reportStatus()
    }

    private func reportStatus() {
        guard running else {
            onStatus?("Permission needed — open macOS permissions below")
            return
        }
        if enabled { onStatus?("Ready — hold, drag, and release the scroll wheel") }
        else { onStatus?(reverseScroll ? "Wheel reversal on · Gestures paused" : "Paused") }
    }

    func shutdown() {
        releaseSyntheticControl()
        // If a short click was pending, complete it before removing the tap.
        if sequence == .tracking, !tracker.didTrigger, let down = pendingDown {
            postMarked(down)
            if let up = down.copy() {
                up.type = .otherMouseUp
                postMarked(up)
            }
        }
        pendingDown = nil
        sequence = .idle
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        running = false
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Recover without leaving a pending button-down unmatched.
            if sequence == .tracking {
                if tracker.didTrigger { sequence = .swallow }
                else { replayPendingDown(); sequence = .passThrough }
                pendingDown = nil
                _ = tracker.end()
            }
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.eventMarker else {
            return Unmanaged.passUnretained(event)
        }
        if type == .scrollWheel {
            if reverseScroll {
                let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                if !excludedApps.contains(bundleID) {
                    ScrollReversal.apply(to: event, enabled: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        // Some drivers report plain movement after the initial down is consumed.
        if type == .mouseMoved {
            guard sequence == .tracking || sequence == .swallow else { return Unmanaged.passUnretained(event) }
        } else if event.getIntegerValueField(.mouseEventButtonNumber) != 2 {
            return Unmanaged.passUnretained(event)
        }
        if type == .otherMouseDown {
            onMiddleClick?()
            let modifiers = event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            guard enabled, modifiers.isEmpty, !excludedApps.contains(bundleID) else {
                sequence = .passThrough
                return Unmanaged.passUnretained(event)
            }
            pendingDown = event.copy()
            pendingDirection = nil
            tracker.begin(at: event.location)
            sequence = .tracking
            return nil
        }
        if sequence == .passThrough {
            if type == .otherMouseUp { sequence = .idle }
            return Unmanaged.passUnretained(event)
        }
        if sequence == .swallow {
            if type == .otherMouseUp { sequence = .idle }
            return nil
        }
        guard sequence == .tracking else { return Unmanaged.passUnretained(event) }
        if type == .otherMouseDragged || type == .mouseMoved {
            let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
            let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
            if let direction = tracker.moveBy(dx: dx, dy: dy, threshold: threshold, natural: natural) {
                pendingDirection = direction
                onAction?("Release the wheel: \(direction.title)")
            }
            return nil
        }
        if type == .otherMouseUp {
            let wasGesture = tracker.end()
            sequence = .idle
            if let direction = pendingDirection {
                pendingDirection = nil
                // Let the physical mouse-up clear before asking Dock to act.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.perform(direction) }
            }
            if !wasGesture, let down = pendingDown {
                // Reinsert the original click at this tap, with the original click count and location.
                down.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
                down.tapPostEvent(proxy)
                pendingDown = nil
                return Unmanaged.passUnretained(event)
            }
            pendingDown = nil
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func replayPendingDown() {
        if let down = pendingDown { postMarked(down) }
    }

    private func postMarked(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        event.post(tap: .cghidEventTap)
    }

    func perform(_ direction: GestureDirection) {
        guard AXIsProcessTrusted() else {
            onStatus?("Permission needed — quit and reopen after allowing access")
            return
        }
        guard !sendingShortcut else { return }
        if direction == .up {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                DispatchQueue.main.async {
                    if let error { self?.onStatus?("Mission Control: \(error.localizedDescription)") }
                    else { self?.onAction?("Opened Mission Control") }
                }
            }
            return
        }
        let key: CGKeyCode
        switch direction {
        case .left: key = 123
        case .right: key = 124
        case .up: key = 126
        case .down: key = 125
        }
        guard CGPreflightPostEventAccess() else {
            onStatus?("macOS is blocking keyboard actions — refresh this app’s control permission")
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let controlDown = CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: true),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            onStatus?("Couldn't send the desktop shortcut")
            return
        }
        // Dock needs a complete modifier transition, not only flags on an arrow.
        sendingShortcut = true
        controlDown.type = .flagsChanged
        controlDown.flags = .maskControl
        // Native arrow events include SecondaryFn. Without it Dock can treat
        // Control+Arrow as ordinary navigation instead of a Spaces shortcut.
        down.flags = [.maskControl, .maskSecondaryFn]
        up.flags = [.maskControl, .maskSecondaryFn]
        postMarked(controlDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in self?.postMarked(down) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) { [weak self] in self?.postMarked(up) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.releaseSyntheticControl()
            self?.onAction?("Sent: \(direction.title)")
        }
    }

    private func releaseSyntheticControl() {
        guard sendingShortcut else { return }
        if let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: 59, keyDown: false) {
            event.type = .flagsChanged
            event.flags = []
            postMarked(event)
        }
        sendingShortcut = false
    }
}
