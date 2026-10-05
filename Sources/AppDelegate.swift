import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let service = MouseService()
    private let defaults = UserDefaults.standard
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusLabel: NSTextField!
    private var activityLabel: NSTextField!
    private var thresholdLabel: NSTextField!
    private var enabledButton: NSButton!
    private var quickControls: MouseControlsPopover!
    private var permissionTimer: Timer?
    private var clickCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["enabled": true, "threshold": 55.0, "natural": false, "reverseScroll": false, "excludedApps": []])
        service.enabled = defaults.bool(forKey: "enabled")
        service.threshold = defaults.double(forKey: "threshold")
        service.natural = defaults.bool(forKey: "natural")
        service.reverseScroll = defaults.bool(forKey: "reverseScroll")
        service.excludedApps = Set(defaults.stringArray(forKey: "excludedApps") ?? [])
        createMenu()
        createWindow()
        service.onStatus = { [weak self] text in self?.statusLabel.stringValue = text }
        service.onAction = { [weak self] action in self?.activityLabel.stringValue = action }
        service.onMiddleClick = { [weak self] in
            guard let self else { return }
            self.clickCount += 1
            self.activityLabel.stringValue = "Middle button detected · \(self.clickCount) press\(self.clickCount == 1 ? "" : "es")"
        }
        service.start()
        // A non-prompting retry catches a permission granted while the settings window is open.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self, !self.service.running, self.service.enabled || self.service.reverseScroll else { return }
            self.service.start()
        }
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        service.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Tom the Mouse")
        statusItem.button?.toolTip = "Tom the Mouse — free mouse gestures"
        quickControls = MouseControlsPopover(
            showSettings: { [weak self] in self?.showSettings() },
            toggleGestures: { [weak self] in self?.toggleFromMenu() },
            quit: { [weak self] in self?.quitApp() })
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleQuickControls)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: "Quit Tom the Mouse", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let root = NSMenuItem()
        root.submenu = appMenu
        appMenu.addItem(settings.copy() as! NSMenuItem)
        let controls = NSMenuItem(title: "Mouse controls…", action: #selector(toggleQuickControls), keyEquivalent: "")
        controls.target = self
        appMenu.addItem(controls)
        appMenu.addItem(.separator())
        appMenu.addItem(quit.copy() as! NSMenuItem)
        mainMenu.addItem(root)
        NSApp.mainMenu = mainMenu
    }

    private func createWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Tom the Mouse"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 800))
        window.contentView = view
        addLabel("Tom the Mouse", x: 30, y: 647, width: 600, height: 38, size: 30, weight: .bold)
        addLabel("Hold. Drag. Release. Let Tom handle the rest.", x: 30, y: 615, width: 600, height: 26, size: 15, color: .secondaryLabelColor)
        let diagram = GestureMap(frame: NSRect(x: 30, y: 414, width: 600, height: 185))
        view.addSubview(diagram)
        enabledButton = NSButton(checkboxWithTitle: "Enable middle-button gestures", target: self, action: #selector(toggleEnabled(_:)))
        enabledButton.frame = NSRect(x: 30, y: 374, width: 420, height: 28)
        enabledButton.state = service.enabled ? .on : .off
        view.addSubview(enabledButton)
        statusLabel = addLabel("Checking permission…", x: 30, y: 345, width: 600, height: 24, size: 12, color: .secondaryLabelColor)
        addLabel("Drag distance", x: 30, y: 307, width: 140, height: 24, size: 13, weight: .medium)
        let slider = NSSlider(value: service.threshold, minValue: 25, maxValue: 140, target: self, action: #selector(changeThreshold(_:)))
        slider.frame = NSRect(x: 170, y: 307, width: 360, height: 24)
        slider.toolTip = "How far the pointer must move before a gesture fires"
        view.addSubview(slider)
        thresholdLabel = addLabel("\(Int(service.threshold)) pt", x: 545, y: 307, width: 85, height: 24, size: 13)
        let natural = NSButton(checkboxWithTitle: "Reverse left/right to follow trackpad-style motion", target: self, action: #selector(changeNatural(_:)))
        natural.frame = NSRect(x: 30, y: 270, width: 600, height: 24)
        natural.state = service.natural ? .on : .off
        view.addSubview(natural)
        button("App exclusions…", x: 30, y: 226, width: 170, action: #selector(editExclusions))
        button("Keyboard shortcuts…", x: 214, y: 226, width: 190, action: #selector(openShortcuts))
        button("macOS permission…", x: 418, y: 226, width: 212, action: #selector(openPermissions))
        activityLabel = addLabel("Button test: press your scroll wheel to check detection.", x: 30, y: 181, width: 600, height: 27, size: 13, weight: .medium)
        addLabel("Hold the wheel, drag, then release to act. A short press stays a normal click.\nHold a modifier before pressing to use normal middle-button dragging.",
                 x: 30, y: 121, width: 600, height: 48, size: 12, color: .secondaryLabelColor)
        addLabel("Setup: enable Control + ←/→/↑/↓ under Keyboard → Keyboard Shortcuts\n→ Mission Control. Quit other apps that remap the middle button.",
                 x: 30, y: 65, width: 600, height: 48, size: 12, color: .secondaryLabelColor)
        addLabel("Created by Muath Fathi Hussin Souki · Free forever · MIT license", x: 30, y: 24, width: 600, height: 22, size: 11, color: .secondaryLabelColor)
        for child in view.subviews where child.frame.origin.y >= 181 {
            let extra: CGFloat = child.frame.origin.y >= 270 ? 90 : 50
            child.setFrameOrigin(NSPoint(x: child.frame.origin.x, y: child.frame.origin.y + extra))
        }
        let reverseScroll = NSButton(checkboxWithTitle: "Reverse scroll wheel (up/down)", target: self, action: #selector(changeScrollReversal(_:)))
        reverseScroll.frame = NSRect(x: 30, y: 318, width: 600, height: 24)
        reverseScroll.state = service.reverseScroll ? .on : .off
        reverseScroll.toolTip = "Reverses a standard mouse wheel. Trackpad scrolling and modifier shortcuts stay unchanged."
        view.addSubview(reverseScroll)
        button("Test ← desktop", x: 30, y: 180, width: 140, action: #selector(testLeft))
        button("Test Mission Control", x: 176, y: 180, width: 172, action: #selector(testUp))
        button("Test app windows", x: 354, y: 180, width: 150, action: #selector(testDown))
        button("Test desktop →", x: 510, y: 180, width: 120, action: #selector(testRight))
    }

    @discardableResult
    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                          size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: x, y: y, width: width, height: height)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isSelectable = false
        window.contentView?.addSubview(label)
        return label
    }

    private func button(_ title: String, x: CGFloat, y: CGFloat, width: CGFloat, action: Selector) {
        let control = NSButton(title: title, target: self, action: action)
        control.bezelStyle = .rounded
        control.frame = NSRect(x: x, y: y, width: width, height: 32)
        window.contentView?.addSubview(control)
    }

    @objc private func toggleQuickControls() {
        guard let button = statusItem.button else { return }
        quickControls.toggle(relativeTo: button, enabled: service.enabled)
    }

    @objc private func showSettings() {
        quickControls.close()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleEnabled(_ sender: NSButton) { updateEnabled(sender.state == .on) }
    @objc private func toggleFromMenu() { updateEnabled(!service.enabled) }
    private func updateEnabled(_ value: Bool) {
        defaults.set(value, forKey: "enabled")
        enabledButton.state = value ? .on : .off
        quickControls.update(enabled: value)
        service.setEnabled(value)
    }

    @objc private func changeThreshold(_ sender: NSSlider) {
        service.threshold = sender.doubleValue.rounded()
        defaults.set(service.threshold, forKey: "threshold")
        thresholdLabel.stringValue = "\(Int(service.threshold)) pt"
    }

    @objc private func changeNatural(_ sender: NSButton) {
        service.natural = sender.state == .on
        defaults.set(service.natural, forKey: "natural")
    }

    @objc private func changeScrollReversal(_ sender: NSButton) {
        let value = sender.state == .on
        defaults.set(value, forKey: "reverseScroll")
        service.setReverseScroll(value)
        activityLabel.stringValue = value ? "Scroll wheel reversed · Trackpad scrolling unchanged" : "Scroll wheel uses the macOS direction"
    }

    @objc private func openPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openShortcuts() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func editExclusions() {
        let alert = NSAlert()
        alert.messageText = "Keep normal mouse behavior in selected apps"
        alert.informativeText = "Enter one app bundle identifier per line, for example com.blenderfoundation.blender. Modifiers also bypass gestures."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 440, height: 140))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView(frame: scroll.bounds)
        text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        text.string = service.excludedApps.sorted().joined(separator: "\n")
        scroll.documentView = text
        alert.accessoryView = scroll
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            let entries = text.string.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            self.service.excludedApps = Set(entries)
            self.defaults.set(Array(self.service.excludedApps).sorted(), forKey: "excludedApps")
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func testLeft() { service.perform(.left) }
    @objc private func testRight() { service.perform(.right) }
    @objc private func testUp() { service.perform(.up) }
    @objc private func testDown() { service.perform(.down) }
}

private final class GestureMap: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18).fill()
        let mouse = NSRect(x: 274, y: 54, width: 52, height: 78)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: mouse, xRadius: 24, yRadius: 24).fill()
        NSColor.controlAccentColor.setStroke()
        let outline = NSBezierPath(roundedRect: mouse, xRadius: 24, yRadius: 24)
        outline.lineWidth = 2
        outline.stroke()
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: 295, y: 102, width: 10, height: 19), xRadius: 5, yRadius: 5).fill()
        drawText("↑  Mission Control", rect: NSRect(x: 195, y: 148, width: 210, height: 23), size: 14)
        drawText("←  Previous desktop", rect: NSRect(x: 25, y: 81, width: 225, height: 23), size: 14)
        drawText("Next desktop  →", rect: NSRect(x: 350, y: 81, width: 225, height: 23), size: 14)
        drawText("↓  App windows", rect: NSRect(x: 200, y: 17, width: 200, height: 23), size: 14)
        drawText("HOLD", rect: NSRect(x: 274, y: 72, width: 52, height: 16), size: 9)
    }

    private func drawText(_ text: String, rect: NSRect, size: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (text as NSString).draw(in: rect, withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph
        ])
    }
}
