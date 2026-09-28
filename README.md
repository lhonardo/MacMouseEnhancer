# MacMouseEnhancer

A lightweight macOS menu bar app that maps mouse side buttons to workspace switching and reverses scroll direction.

## Features

- **Side button workspace switching** — back/forward mouse buttons switch between Mission Control spaces with the native slide animation
- **Scroll reversal** — flips scroll direction on all axes (natural scrolling toggle)
- **Configurable button assignments** — assign any mouse button to prev/next workspace via the settings panel

## Requirements

- macOS 13 Ventura or later (Apple Silicon)
- A mouse with side buttons (back/forward)
- Accessibility permission

## Installation

1. Clone the repo and build:
   ```
   git clone https://github.com/lhonardo/MacMouseEnhancer.git
   cd MacMouseEnhancer
   swift build -c release
   ```

2. Create the app bundle and copy the binary:
   ```
   mkdir -p MacMouseEnhancer.app/Contents/MacOS
   cp .build/arm64-apple-macosx/release/MacMouseEnhancer MacMouseEnhancer.app/Contents/MacOS/MacMouseEnhancer
   cp Info.plist MacMouseEnhancer.app/Contents/Info.plist
   ```

3. Move `MacMouseEnhancer.app` to `/Applications`

4. Open the app — macOS will prompt for **Accessibility permission**. Grant it in System Settings → Privacy & Security → Accessibility.

5. Add to **Login Items** (System Settings → General → Login Items) to run at startup.

## Usage

Click the mouse icon in the menu bar to access controls:

- **Workspace Switch: ON/OFF** — toggle side button switching
- **Button Assignments…** — click Assign, then press any mouse button to remap prev/next workspace
- **Scroll Reversal: ON/OFF** — toggle scroll direction reversal
- **Accessibility Permissions…** — open the relevant System Settings pane
- **Quit**

## How it works

MacMouseEnhancer installs a `CGEventTap` at the HID level to intercept mouse button events before they reach any app. Workspace switching is triggered via the macOS symbolic hotkey system (`CGSGetSymbolicHotKeyValue` / `CGSSetSymbolicHotKeyValue`) which produces the native animated space transition.

## Notes

- Requires Accessibility permission — this is needed for the `CGEventTap` to intercept mouse events globally
- Uses private `SkyLight.framework` APIs for the animated workspace transition (same approach as Mac Mouse Fix)
- No network access, no telemetry, no App Store
