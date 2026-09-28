import Cocoa

class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private var prevLabel: NSTextField!
    private var nextLabel: NSTextField!
    private var prevAssignBtn: NSButton!
    private var nextAssignBtn: NSButton!

    // Tracks which row is currently in listening mode
    private enum ListeningFor { case prev, next }
    private var listeningFor: ListeningFor?

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 210),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "MacMouseEnhancer — Button Assignments"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        super.init(window: panel)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        let header = label("Workspace Switching — Button Assignments", bold: true, size: 13)
        let sub    = label("Click Assign, then press a side mouse button to map it.\n(Left clicks are ignored during assignment.)", bold: false, size: 11, color: .secondaryLabelColor)

        let prevRow  = label("← Previous Workspace", bold: false, size: 12)
        prevLabel    = label("", bold: false, size: 12, color: .secondaryLabelColor, mono: true)
        prevAssignBtn = actionButton("Assign", action: #selector(assignPrevTapped))

        let nextRow  = label("→ Next Workspace", bold: false, size: 12)
        nextLabel    = label("", bold: false, size: 12, color: .secondaryLabelColor, mono: true)
        nextAssignBtn = actionButton("Assign", action: #selector(assignNextTapped))

        let note = label(
            "Tip: enable Mission Control shortcuts in\nSystem Settings → Keyboard → Keyboard Shortcuts → Mission Control.",
            bold: false, size: 10, color: .tertiaryLabelColor
        )
        note.maximumNumberOfLines = 2

        for v in [header, sub, prevRow, prevLabel!, prevAssignBtn!, nextRow, nextLabel!, nextAssignBtn!, note] as [NSView] {
            cv.addSubview(v)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),

            sub.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            sub.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),

            prevRow.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 18),
            prevRow.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            prevRow.widthAnchor.constraint(equalToConstant: 170),

            prevLabel.centerYAnchor.constraint(equalTo: prevRow.centerYAnchor),
            prevLabel.leadingAnchor.constraint(equalTo: prevRow.trailingAnchor, constant: 8),
            prevLabel.widthAnchor.constraint(equalToConstant: 100),

            prevAssignBtn.centerYAnchor.constraint(equalTo: prevRow.centerYAnchor),
            prevAssignBtn.leadingAnchor.constraint(equalTo: prevLabel.trailingAnchor, constant: 8),

            nextRow.topAnchor.constraint(equalTo: prevRow.bottomAnchor, constant: 14),
            nextRow.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            nextRow.widthAnchor.constraint(equalToConstant: 170),

            nextLabel.centerYAnchor.constraint(equalTo: nextRow.centerYAnchor),
            nextLabel.leadingAnchor.constraint(equalTo: nextRow.trailingAnchor, constant: 8),
            nextLabel.widthAnchor.constraint(equalToConstant: 100),

            nextAssignBtn.centerYAnchor.constraint(equalTo: nextRow.centerYAnchor),
            nextAssignBtn.leadingAnchor.constraint(equalTo: nextLabel.trailingAnchor, constant: 8),

            note.topAnchor.constraint(equalTo: nextRow.bottomAnchor, constant: 18),
            note.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            note.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
        ])

        refreshLabels()
    }

    private func label(_ text: String, bold: Bool, size: CGFloat, color: NSColor = .labelColor, mono: Bool = false) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = mono
            ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : (bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size))
        tf.textColor = color
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    private func actionButton(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - Show

    func showWindow() {
        refreshLabels()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Assign button actions

    @objc private func assignPrevTapped() {
        if listeningFor == .prev {
            cancelListening()
        } else {
            startListening(for: .prev)
        }
    }

    @objc private func assignNextTapped() {
        if listeningFor == .next {
            cancelListening()
        } else {
            startListening(for: .next)
        }
    }

    // MARK: - Listening mode

    private func startListening(for row: ListeningFor) {
        EventTapManager.shared.buttonListeningCallback = nil
        listeningFor = row

        let (btn, lbl) = row == .prev ? (prevAssignBtn!, prevLabel!) : (nextAssignBtn!, nextLabel!)
        btn.title = "Cancel"
        lbl.stringValue = "Press a button…"
        lbl.textColor = .systemOrange

        EventTapManager.shared.buttonListeningCallback = { [weak self] capturedBtn in
            guard let self else { return }
            if row == .prev {
                EventTapManager.shared.prevButton = capturedBtn
            } else {
                EventTapManager.shared.nextButton = capturedBtn
            }
            self.listeningFor = nil
            btn.title = "Assign"
            self.refreshLabels()
        }

        EventTapManager.shared.restartTapIfNeeded()
    }

    private func cancelListening() {
        EventTapManager.shared.buttonListeningCallback = nil
        listeningFor = nil
        prevAssignBtn.title = "Assign"
        nextAssignBtn.title = "Assign"
        refreshLabels()
    }

    private func refreshLabels() {
        if listeningFor != .prev {
            prevLabel.stringValue = "Button \(EventTapManager.shared.prevButton)"
            prevLabel.textColor = .secondaryLabelColor
        }
        if listeningFor != .next {
            nextLabel.stringValue = "Button \(EventTapManager.shared.nextButton)"
            nextLabel.textColor = .secondaryLabelColor
        }
    }
}
