import Cocoa
import ApplicationServices
import Darwin

class EventTapManager {
    static let shared = EventTapManager()

    var sideButtonsEnabled: Bool = true {
        didSet { savePreferences() }
    }
    var scrollReversalEnabled: Bool = true {
        didSet { savePreferences() }
    }
    var scrollSpeedMultiplier: Double = 3.0 {
        didSet { savePreferences() }
    }
    var prevButton: Int = 3 {
        didSet { savePreferences() }
    }
    var nextButton: Int = 4 {
        didSet { savePreferences() }
    }

    // Set to capture the next button press for binding. Cleared after one use.
    var buttonListeningCallback: ((Int) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {
        loadPreferences()
    }

    // MARK: - Preferences

    private func loadPreferences() {
        let d = UserDefaults.standard
        if d.object(forKey: "sideButtonsEnabled") != nil   { sideButtonsEnabled   = d.bool(forKey: "sideButtonsEnabled") }
        if d.object(forKey: "scrollReversalEnabled") != nil { scrollReversalEnabled = d.bool(forKey: "scrollReversalEnabled") }
        if d.object(forKey: "scrollSpeedMultiplier") != nil  { scrollSpeedMultiplier  = d.double(forKey: "scrollSpeedMultiplier") }
        if d.object(forKey: "prevWorkspaceButton") != nil  { prevButton = d.integer(forKey: "prevWorkspaceButton") }
        if d.object(forKey: "nextWorkspaceButton") != nil  { nextButton = d.integer(forKey: "nextWorkspaceButton") }
    }

    private func savePreferences() {
        let d = UserDefaults.standard
        d.set(sideButtonsEnabled,   forKey: "sideButtonsEnabled")
        d.set(scrollReversalEnabled, forKey: "scrollReversalEnabled")
        d.set(scrollSpeedMultiplier,  forKey: "scrollSpeedMultiplier")
        d.set(prevButton, forKey: "prevWorkspaceButton")
        d.set(nextButton, forKey: "nextWorkspaceButton")
    }

    // MARK: - Tap lifecycle

    func start() {
        guard eventTap == nil else { return }
        installEventTap()
    }

    // Called when a feature toggle changes — just keep the same tap running,
    // decisions are made at handle-time not install-time.
    func restartTapIfNeeded() {
        guard eventTap == nil else { return }
        installEventTap()
    }

    private func installEventTap() {
        // Intercept ALL mouse-button and scroll events unconditionally.
        // Feature flags are checked inside handleEvent, not here.
        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)   |
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,          // intercept at HID level, before any app sees it
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let mgr = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
                return mgr.handleEvent(type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap = tap else {
            Unmanaged<EventTapManager>.fromOpaque(selfPtr).release()
            print("MouseFix: Failed to create event tap — grant Accessibility permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource!, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Event handling

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .otherMouseDown, .leftMouseDown, .rightMouseDown:
            return handleMouseDown(type: type, event: event)

        case .otherMouseUp:
            // Consume the up-event for whichever button we own, so apps don't see the release.
            if buttonListeningCallback == nil && sideButtonsEnabled {
                let btn = Int(event.getIntegerValueField(.mouseEventButtonNumber))
                if btn == prevButton || btn == nextButton {
                    return nil
                }
            }
            return Unmanaged.passRetained(event)

        case .scrollWheel:
            guard scrollReversalEnabled else { return Unmanaged.passRetained(event) }
            return reverseScroll(event)

        default:
            return Unmanaged.passRetained(event)
        }
    }

    // MARK: - Mouse button down

    private func handleMouseDown(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let btn = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        if let callback = buttonListeningCallback {
            if type == .leftMouseDown { return Unmanaged.passRetained(event) }
            buttonListeningCallback = nil
            DispatchQueue.main.async { callback(btn) }
            return nil
        }

        guard sideButtonsEnabled, type == .otherMouseDown else {
            return Unmanaged.passRetained(event)
        }

        if btn == prevButton {
            sendWorkspaceSwitch(goLeft: true)
            return nil
        }
        if btn == nextButton {
            sendWorkspaceSwitch(goLeft: false)
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func sendWorkspaceSwitch(goLeft: Bool) {
        // SHK 79 = move left a space, 81 = move right a space
        let shk: UInt32 = goLeft ? 79 : 81
        postSymbolicHotKey(shk)
    }

    private func postSymbolicHotKey(_ shk: UInt32) {
        let lib = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

        typealias GetSHKFn     = @convention(c) (UInt32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<UInt32>) -> Int32
        typealias SetSHKFn     = @convention(c) (UInt32, UInt16, UInt32, UInt32) -> Int32
        typealias IsSHKEnabledFn = @convention(c) (UInt32) -> Bool
        typealias SetSHKEnabledFn = @convention(c) (UInt32, Bool) -> Void

        guard let lib,
              let getSym     = dlsym(lib, "CGSGetSymbolicHotKeyValue"),
              let setSym     = dlsym(lib, "CGSSetSymbolicHotKeyValue"),
              let isEnabSym  = dlsym(lib, "CGSIsSymbolicHotKeyEnabled"),
              let setEnabSym = dlsym(lib, "CGSSetSymbolicHotKeyEnabled")
        else { return }

        let getFn     = unsafeBitCast(getSym,     to: GetSHKFn.self)
        let setFn     = unsafeBitCast(setSym,     to: SetSHKFn.self)
        let isEnabFn  = unsafeBitCast(isEnabSym,  to: IsSHKEnabledFn.self)
        let setEnabFn = unsafeBitCast(setEnabSym, to: SetSHKEnabledFn.self)

        var keq:  UInt16 = 0
        var vkc:  UInt32 = 0
        var mods: UInt32 = 0
        getFn(shk, &keq, &vkc, &mods)

        let kVKCNull:   UInt32 = 65535
        let kKeqNull:   UInt16 = 65535
        let kFnNumpad:  UInt32 = 0x800 | 0x200  // kCGSFunctionKeyMask | kCGSNumericPadKeyMask

        // Determine usable vkc
        var usableVKC = kVKCNull
        if isEnabFn(shk) {
            usableVKC = (keq == kKeqNull) ? vkc : kVKCNull
        }

        let postVKC:  UInt32
        let postMods: UInt32

        if usableVKC == kVKCNull {
            // No usable binding — install a permanent unreachable one (VKC = shk + 400, fn|numpad flags)
            setEnabFn(shk, true)
            let newVKC:  UInt32 = shk + 400
            let newMods: UInt32 = kFnNumpad
            setFn(shk, kKeqNull, newVKC, newMods)
            postVKC  = newVKC
            postMods = newMods
        } else {
            postVKC  = usableVKC
            postMods = mods
        }

        // Post with NULL source to cgSessionEventTap — WindowServer treats this as hardware and animates
        let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(postVKC), keyDown: true)
        let up   = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(postVKC), keyDown: false)
        down?.flags = CGEventFlags(rawValue: UInt64(postMods))
        up?.flags   = []
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    // MARK: - Scroll reversal

    private func reverseScroll(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let m = scrollSpeedMultiplier
        let d1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let d2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let f1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let f2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let p1 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let p2 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(Double(-d1) * m))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(Double(-d2) * m))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -f1 * m)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -f2 * m)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -p1 * m)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -p2 * m)

        return Unmanaged.passRetained(event)
    }
}
