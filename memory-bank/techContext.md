# Tech Context

## Stack
- Language: Swift
- UI: SwiftUI
- App lifecycle/platform: macOS AppKit + SwiftUI (`NSApplicationDelegateAdaptor`, `NSWindow`, `MenuBarExtra`)
- Persistence: `UserDefaults`
- Async/data: `URLSession`, `Codable`, Combine
- Notifications: `UserNotifications`
- Keyboard monitoring: `NSEvent` local/global monitors + AX trust prompt

## Project Layout
- `kitkat/` app source
- `kitkat/Model/` timer, monitor, quote models
- `kitkat/Utils/` API client, logger, day-count store
- `kitkatTests/` Swift Testing unit tests (mostly REST client)
- `kitkatUITests/` XCTest UI tests template

## Build/Test Commands
- Preferred test command: `xcodebuild test -scheme kitkat -destination 'platform=macOS'`
- Practical fallback used recently: `xcodebuild build -scheme kitkat -destination 'platform=macOS' -quiet`

## Known Environment Notes
- In this environment, `xcodebuild test` has intermittently failed at launch with Xcode assertion:
  - `IDELaunchServicesLauncher` / `childPID > 0`
- Build-only command has succeeded for recent changes.
