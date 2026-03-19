# Active Context

## Current Focus
- Stabilize and clarify the day-of-week counting semantics.
- Improve weekly table readability and progress cues.
- Surface keyboard-listener permission status in the main window.

## Recent Changes (March 19, 2026)
- Added keyboard access status model and monitor abstractions:
  - `KeyboardAccessStatus` (`.connected` / `.disconnected`) with shared icon/text semantics.
  - `KeyboardAccessTrustChecking` + `AXKeyboardAccessTrustChecker` for prompt vs non-prompt AX checks.
  - `KeyboardAccessMonitoring` protocol to make app-level refresh flows testable.
- Updated `GlobalEventMonitor`:
  - Added delegate callback for keyboard access status updates.
  - Added `refreshKeyboardAccessStatus(promptForPermission:)`.
  - `start()` now performs one prompt-enabled status check.
  - `stop()` now removes both local and global event monitors.
- Updated app wiring in `kitkatApp` / `AppDelegate`:
  - Added `@Published keyboardAccessStatus`.
  - Added 5-second periodic status polling and app-activation refresh (both non-prompt).
  - Bound status into SwiftUI state with an additional Combine sink.
- Updated `ContentView`:
  - Added a keyboard status row in the main window.
  - Connected state uses `keyboard.fill` tinted green.
  - Disconnected state uses `keyboard.badge.exclamationmark` with warning tint.
- Added unit tests covering:
  - status icon/text mappings,
  - trusted/untrusted mapping in monitor refresh,
  - prompt-enabled vs unprompted refresh path,
  - app-activation and periodic refresh behavior dispatch.

## Recent Changes (March 11-12, 2026)
- Added `WorkweekGoalCalculator.dailyTarget(from:)` to centralize goal computation.
- Updated the workweek goal rule to enforce a minimum daily target of `5`:
  - `dailyTarget = max(5, ceil(totalCountAcrossAllDays / 5.0))`
  - The existing legacy averaging basis remains in place (sum all day buckets, divide by 5).
- Updated coffee-goal UI semantics to treat goal as always set:
  - Progress label consistently shows `today / goal`.
  - Removed "goal not set yet" accessibility message path.
- Added unit tests for minimum-floor and round-up behavior at totals `0, 20, 25, 26, 29`, plus a legacy-basis coverage case.
- Updated day rollover logic in `updateCountForCurrentDay()`:
  - On weekday change, reset the **current** day count to `0`.
  - Same call then increments current day to `1`.
- Added "Workweek Average Goal" UI block in `ContentView`.
- Implemented average calculation as:
  - `rawAverage = totalCountAcrossAllDays / 5.0`
  - round down when fraction `< 0.5`
  - round up when fraction `>= 0.5`
- Styled current weekday row in table as dark green and bold.
- Removed unused local `message` variable from `kitkatApp.onAppear` and replaced with logging.
- Added coffee-cup progress UI to the left of "Workweek Average Goal":
  - Fill level maps to `todayCount / averagePerWorkdayGoal` (clamped to `0...1`).
  - Reached state (`todayCount >= averagePerWorkdayGoal`, with non-zero goal) shows "Coffee unlocked" messaging and steam icon.
- Refined coffee UI visuals after feedback:
  - Cup body now uses a tapered custom shape (wider top, narrower base).
  - Coffee fill uses a horizontal liquid level clipped inside the cup silhouette.

## Active Decisions
- Current day is emphasized in the weekly table for fast scanning.
- Daily target uses `max(5, ceil(totalAcrossAllDays / 5.0))`.
- Counts are persisted via `DayOfTheWeekCounterStore` in `UserDefaults`.

## Open Considerations
- If product expectation changes, revisit whether `.5` should round down instead.
- Day reset only occurs when `updateCountForCurrentDay()` runs (i.e., at break completion), not at midnight.
