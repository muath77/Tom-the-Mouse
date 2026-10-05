import AppKit

/// Transient controls avoid entering NSMenu's modal tracking loop.
final class MouseControlsPopover: NSObject {
    private let popover = NSPopover()
    private let pauseButton = NSButton()
    private let showSettingsAction: () -> Void
    private let toggleGesturesAction: () -> Void
    private let quitAction: () -> Void

    init(showSettings: @escaping () -> Void, toggleGestures: @escaping () -> Void,
         quit: @escaping () -> Void) {
        showSettingsAction = showSettings
        toggleGesturesAction = toggleGestures
        quitAction = quit
        super.init()
        let controller = NSViewController()
        let view = DismissibleControlsView(frame: NSRect(x: 0, y: 0, width: 250, height: 226))
        view.dismiss = { [weak self] in self?.close() }
        controller.view = view
        let title = NSTextField(labelWithString: "Tom the Mouse")
        title.font = .boldSystemFont(ofSize: 16)
        title.frame = NSRect(x: 18, y: 188, width: 215, height: 22)
        view.addSubview(title)
        addButton("Settings…", at: 142, selector: #selector(settings), in: view)
        pauseButton.target = self
        pauseButton.action = #selector(MouseControlsPopover.toggleGestures)
        pauseButton.bezelStyle = .rounded
        pauseButton.frame = NSRect(x: 14, y: 102, width: 222, height: 32)
        view.addSubview(pauseButton)
        addButton("Close", at: 62, selector: #selector(close), in: view)
        addButton("Quit Tom the Mouse", at: 18, selector: #selector(MouseControlsPopover.quit), in: view)
        popover.contentViewController = controller
        popover.contentSize = view.frame.size
        popover.behavior = .transient
        popover.animates = false
    }

    private func addButton(_ title: String, at y: CGFloat, selector: Selector, in view: NSView) {
        let button = NSButton(title: title, target: self, action: selector)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 14, y: y, width: 222, height: 32)
        if title == "Close" { button.keyEquivalent = "\u{1b}" }
        view.addSubview(button)
    }

    func update(enabled: Bool) {
        pauseButton.title = enabled ? "Pause gestures" : "Resume gestures"
    }

    func toggle(relativeTo button: NSStatusBarButton, enabled: Bool) {
        if popover.isShown { close(); return }
        update(enabled: enabled)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        if let view = popover.contentViewController?.view {
            view.window?.makeFirstResponder(view)
        }
    }

    @objc func close() { popover.performClose(nil) }
    @objc private func settings() { close(); showSettingsAction() }
    @objc private func toggleGestures() { close(); toggleGesturesAction() }
    @objc private func quit() { close(); quitAction() }
}

private final class DismissibleControlsView: NSView {
    var dismiss: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
}
