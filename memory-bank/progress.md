# Progress

## What Works
- Menu bar countdown updates every minute.
- Keyboard activity detection advances countdown state.
- Idle detection resets countdown after prolonged inactivity.
- Break trigger sends local notification and opens break window.
- Quote fetching works through `RESTAPIClient` + `QuoteViewModel`.
- Weekday counts persist across launches.
- Weekly table displays all days.
- Date-level history now persists by local date key (`yyyy-MM-dd`) with rolling 13-week retention.
- Weekday averages UI now shows a Mon-Fri bar chart (last 13 weeks), without an averages table.
- Weekday average values are integer-only and always rounded up.
- Weekday most-productive UI now shows a Mon-Fri bar chart (last 13 weeks) using rolling per-weekday max.
- Dashboard uses a native two-row layout: `Count & Idle` and `Workweek Average Goal` on the first row; `Daily Streak`, `Weekday Averages`, and `Weekday Most Productive` on the second.
- Daily streak table has fixed height to keep all rows visible.
- Current day row now highlighted (dark green + bold).
- Workweek average goal metric is displayed.
- Daily target now has an enforced minimum of `5`, includes weekend averages in total, and divides by fixed weekday divisor `5`.
- Coffee-cup progress indicator displays today's progress toward the average goal and unlocks at completion.
- Keyboard listener status now appears in the main window with connected/disconnected icon states.
- Break popup now uses adaptive system-material styling that stays readable in both dark and light themes.
- Keyboard-monitor status now reflects macOS Input Monitoring permission, and any received key event immediately resumes the countdown and clears idle count.

## Recently Completed
- Removed the retired HTML/WebKit overview feature and restored the native two-row dashboard layout.
- Redesigned the break popup window to be dark/light friendly while keeping the large overlay:
  - removed fixed light-only window background tint,
  - added adaptive material backdrop + centered panel,
  - updated popup typography and action-row structure,
  - switched to semantic button styles (`Close` bordered, `Get Quote` bordered-prominent),
  - removed obsolete popup styling/commented code.
- Added `WorkweekGoalCalculator` as a shared goal-computation helper.
- Updated goal formula to use all-day averages with fixed weekday divisor: `max(5, ceil(sum(allDailyAverages) / 5.0))`.
- Updated coffee goal text/accessibility to remove "goal not set yet" semantics.
- Updated unit tests for goal floor, weekend-included totals, and fixed-divisor (`5`) averaging behavior.
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
- Added `DailyCountHistoryStore` with record + prune behavior for 13-week rolling history.
- Added `WeekdayAverageCalculator` for Mon-Fri averages from date history.
- Added weekday productive-peak analytics with tie winner metadata from date history.
- Wired `dailyHistoryCounts` state through `CountDownTimer` -> `AppDelegate` -> `kitkatApp` -> `ContentView`.
- Reflowed `ContentView` to place Count/Idle beside Workweek Average Goal on row 1 and keep Daily Streak + both weekday charts on row 2.
- Added test coverage for:
  - history bootstrap/load/save/prune,
  - weekday average bucketing/skip-missing-day/weekend exclusion/boundary filtering,
  - weekday productive peak replacement/falloff/weekend exclusion/tie winners,
  - break-path history increment + prune integration.

## Known Issues / Risks
- `xcodebuild build` and `xcodebuild test` are unstable in this environment due Xcode launcher/CoreSimulator failures; on July 20, 2026, the unavailable simulator service caused `SwiftDataMacros` to return a malformed response during compilation.
- A global variable pattern (`dayOfWeekCounts`, `g_dayOfWeek`) may complicate future scaling/tests.
- Date-level history currently uses another global (`dailyHistoryCounts`) in `CountDownTimer.swift`.
- Day rollover is event-driven at break updates, not time-driven at midnight.

## Next Logical Steps
- Add unit tests for weekday rollover and average rounding rules.
- Consider moving day-count state into a dedicated model/service to reduce global mutable state.
- Consider merging legacy weekday counter and date-history logic into one service to remove duplicate mutable global state.
