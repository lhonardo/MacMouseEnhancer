import Cocoa
import ApplicationServices

// CGEventType raw values for extra mouse buttons
private let kCGEventOtherMouseDown: CGEventType = .otherMouseDown
private let kCGEventOtherMouseUp: CGEventType = .otherMouseUp

class EventTapManager {
    static let shared = EventTapManager()

    var sideButtonsEnabled: Bool = true {
        didSet { savePreferences() }
    }
    var scrollReversalEnabled: Bool = true {
        didSet { savePreferences() }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let prefsSideButtons = "sideButtonsEnabled"
    private let prefsScrollReversal = "scrollReversalEnabled"

    private init() {
        loadPreferences()
    }

    // MARK: - Preferences

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: prefsSideButtons) != nil {
            sideButtonsEnabled = defaults.bool(forKey: prefsSideButtons)
        }
        if defaults.object(forKey: prefsScrollReversal) != nil {
            scrollReversalEnabled = defaults.bool(forKey: prefsScrollReversal)
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(sideButtonsEnabled, forKey: prefsSideButtons)
        UserDefaults.standard.set(scrollReversalEnabled, forKey: prefsScrollReversal)
    }

    // MARK: - Event Tap

    func start() {
        guard eventTap == nil else { return }
        installEventTap()
    }

    func restartTapIfNeeded() {
        stop()
        if sideButtonsEnabled || scrollReversalEnabled {
            installEventTap()
        }
    }

    private func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func installEventTap() {
        guard sideButtonsEnabled || scrollReversalEnabled else { return }

        // Build event mask for the events we care about
        var mask: CGEventMask = 0
        if sideButtonsEnabled {
            mask |= (1 << CGEventType.otherMouseDown.rawValue)
            mask |= (1 << CGEventType.otherMouseUp.rawValue)
        }
        if scrollReversalEnabled {
            mask |= (1 << CGEventType.scrollWheel.rawValue)
        }

        // We need a raw pointer to self to use as callback userInfo
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap = tap else {
            // Release retained self if tap creation failed
            Unmanaged<EventTapManager>.fromOpaque(selfPtr).release()
            print("MouseFix: Failed to create event tap. Accessibility permission required.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .otherMouseDown, .otherMouseUp:
            return handleSideButton(proxy: proxy, type: type, event: event)
        case .scrollWheel:
            return handleScroll(proxy: proxy, event: event)
        default:
            return Unmanaged.passRetained(event)
        }
    }

    // MARK: - Side Button Workspace Switching

    private func handleSideButton(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard sideButtonsEnabled else { return Unmanaged.passRetained(event) }

        // CGEventField for mouse button number: kCGMouseEventButtonNumber = 9
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

        // Button 3 = back (index finger side), Button 4 = forward (thumb side)
        // On most mice: button 3 = back, button 4 = forward
        guard buttonNumber == 3 || buttonNumber == 4 else {
            return Unmanaged.passRetained(event)
        }

        // Only act on mouse-down to avoid double-firing
        guard type == .otherMouseDown else {
            return nil // consume the up event too
        }

        if buttonNumber == 3 {
            // Back button -> move to previous workspace (Control+Left)
            sendWorkspaceSwitch(goLeft: true)
        } else {
            // Forward button -> move to next workspace (Control+Right)
            sendWorkspaceSwitch(goLeft: false)
        }

        // Consume the original event so it doesn't propagate
        return nil
    }

    private func sendWorkspaceSwitch(goLeft: Bool) {
        let keyCode: CGKeyCode = goLeft ? 123 : 124 // Left = 123, Right = 124
        let flags: CGEventFlags = [.maskControl]

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    // MARK: - Scroll Reversal

    private func handleScroll(proxy: CGEventTapProxy, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard scrollReversalEnabled else { return Unmanaged.passRetained(event) }

        // Flip scroll delta values for both axes
        let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)

        let fixedDelta1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedDelta2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

        let pointDelta1 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let pointDelta2 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)

        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedDelta1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixedDelta2)

        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDelta1)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -pointDelta2)

        return Unmanaged.passRetained(event)
    }
}
