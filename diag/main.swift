import Cocoa
import ApplicationServices

// Quick diagnostic tool to print all mouse button events
let app = NSApplication.shared
app.setActivationPolicy(.regular)

class DiagDelegate: NSObject, NSApplicationDelegate {
    var tap: CFMachPort?

    func applicationDidFinishLaunching(_ n: Notification) {
        let mask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                let btn = event.getIntegerValueField(.mouseEventButtonNumber)
                print("EVENT type=\(type.rawValue) button=\(btn)")
                fflush(stdout)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        if let tap = tap {
            let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("Listening for mouse clicks. Press any mouse button...")
        } else {
            print("ERROR: could not create event tap (need Accessibility permission)")
        }
    }
}

let d = DiagDelegate()
app.delegate = d
app.run()
