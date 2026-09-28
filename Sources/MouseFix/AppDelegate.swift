import Cocoa
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTapManager: EventTapManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        checkAccessibilityPermissions()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MacMouseEnhancer")
            button.image?.isTemplate = true
        }
        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "MacMouseEnhancer", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Workspace switching toggle + settings
        let sideBtnItem = NSMenuItem(
            title: EventTapManager.shared.sideButtonsEnabled
                ? "Workspace Switch: ON" : "Workspace Switch: OFF",
            action: #selector(toggleSideButtons),
            keyEquivalent: ""
        )
        sideBtnItem.target = self
        sideBtnItem.state = EventTapManager.shared.sideButtonsEnabled ? .on : .off
        menu.addItem(sideBtnItem)

        let assignItem = NSMenuItem(
            title: "  Button Assignments…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        assignItem.target = self
        menu.addItem(assignItem)

        // Scroll reversal toggle
        let scrollTitle = EventTapManager.shared.scrollReversalEnabled
            ? "Scroll Reversal: ON"
            : "Scroll Reversal: OFF"
        let scrollItem = NSMenuItem(
            title: scrollTitle,
            action: #selector(toggleScrollReversal),
            keyEquivalent: ""
        )
        scrollItem.target = self
        scrollItem.state = EventTapManager.shared.scrollReversalEnabled ? .on : .off
        menu.addItem(scrollItem)

        menu.addItem(NSMenuItem.separator())

        let permItem = NSMenuItem(
            title: "Accessibility Permissions...",
            action: #selector(openAccessibilityPrefs),
            keyEquivalent: ""
        )
        permItem.target = self
        menu.addItem(permItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit MacMouseEnhancer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleSideButtons() {
        EventTapManager.shared.sideButtonsEnabled.toggle()
        EventTapManager.shared.restartTapIfNeeded()
        updateMenu()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func toggleScrollReversal() {
        EventTapManager.shared.scrollReversalEnabled.toggle()
        EventTapManager.shared.restartTapIfNeeded()
        updateMenu()
    }

    @objc private func openAccessibilityPrefs() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func checkAccessibilityPermissions() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if trusted {
            EventTapManager.shared.start()
        } else {
            // Poll until granted
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    EventTapManager.shared.start()
                    self?.updateMenu()
                }
            }
        }
    }
}
