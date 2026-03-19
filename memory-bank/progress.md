# Progress

## What Works
- Menu bar countdown updates every minute.
- Keyboard activity detection advances countdown state.
- Idle detection resets countdown after prolonged inactivity.
- Break trigger sends local notification and opens break window.
- Quote fetching works through `RESTAPIClient` + `QuoteViewModel`.
- Weekday counts persist across launches.
- Weekly table displays all days.
- Current day row now highlighted (dark green + bold).
- Workweek average goal metric is displayed.
- Daily target now has an enforced minimum of `5`, and increases only when computed average exceeds `5`.
- Coffee-cup progress indicator displays today's progress toward the average goal and unlocks at completion.
- Keyboard listener status now appears in the main window with connected/disconnected icon states.

## Recently Completed
- Added `WorkweekGoalCalculator` as a shared goal-computation helper.
- Updated goal formula to `max(5, ceil(totalAcrossAllDays / 5.0))`.
- Updated coffee goal text/accessibility to remove "goal not set yet" semantics.
- Added unit tests for goal floor, rounding-up behavior, and legacy averaging basis coverage.
- Fixed daily rollover behavior to reset current day on first update of a new day.
- Added average-per-workday calculation and UI display.
- Added coffee-cup UI with animated fill tied to today's count vs average goal, with unlocked state messaging.
- Reworked coffee-cup drawing to a tapered cup silhouette with true liquid-level fill for clearer affordance.
- Removed unused variable warning in `kitkatApp` by replacing dead state updates with logging.
- Added keyboard access status pipeline:
  - `GlobalEventMonitor` now reports AX trust status through a delegate.
  - `AppDelegate` now publishes `keyboardAccessStatus`.
  - App performs non-prompt permission refresh on app activation and a 5-second poll timer.
- Added keyboard status UI in `ContentView` using SF Symbols:
  - connected: `keyboard.fill` (green)
  - disconnected: `keyboard.badge.exclamationmark`
- Added unit tests for keyboard status mapping and refresh behavior in monitor + app delegate flow.

## Known Issues / Risks
- Full `xcodebuild test` execution is unstable in this environment due launcher assertion.
- A global variable pattern (`dayOfWeekCounts`, `g_dayOfWeek`) may complicate future scaling/tests.
- Day rollover is event-driven at break updates, not time-driven at midnight.

## Next Logical Steps
- Add unit tests for weekday rollover and average rounding rules.
- Consider moving day-count state into a dedicated model/service to reduce global mutable state.
- Decide and document explicit product rule for exactly `.5` rounding behavior.
