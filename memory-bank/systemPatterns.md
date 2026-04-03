# System Patterns

## Architecture Overview
- Entry point: `kitkatApp` (`@main` SwiftUI App).
- Coordination: `AppDelegate` owns runtime services and published app state.
- Timer engine: `CountDownTimer` drives countdown + break trigger.
- Input signal: `GlobalEventMonitor` marks user activity via keyboard events.
- Keyboard access state: `GlobalEventMonitor` reports AX-trust status to `AppDelegate`.
- Persistence: `DayOfTheWeekCounterStore` reads/writes weekday counts from `UserDefaults`.
- History persistence: `DailyCountHistoryStore` reads/writes date-level daily counts (`yyyy-MM-dd`) and prunes to rolling 13 weeks.
- Goal calculation: `WorkweekGoalCalculator` computes the displayed daily target.
- Weekday analytics: `WeekdayAverageCalculator` computes Mon-Fri averages and Mon-Fri productive peaks from the rolling history.
- UI: `ContentView` renders timer, idle count, daily streak table, weekday-average chart, weekday-productive chart, and workweek goal card.

## Core Runtime Flow
1. `AppDelegate` creates `CountDownTimer` + `GlobalEventMonitor`.
2. `applicationDidFinishLaunching` starts timer and monitors.
3. Keyboard events call `continueCounter()` -> timer state `run`.
4. Every minute, timer tick:
- decrements countdown only when in `run` state
- increments idle count when paused
- resets countdown if idle reaches period
5. When countdown reaches zero:
- local notification is scheduled
- break window is shown
- day count is updated/persisted
- date-level daily history is incremented and pruned to the 13-week window
- published state is pushed to SwiftUI.
6. Keyboard access status updates:
- Prompt-enabled trust check on monitor start.
- Non-prompt trust checks on app activation and periodic polling.
- `AppDelegate` publishes `keyboardAccessStatus` to SwiftUI bindings.

## State Propagation Pattern
- `AppDelegate` exposes `@Published` properties (`menuText`, `dayOfTheWeekCounts`, `remainingSeconds`, `idleCount`, `keyboardAccessStatus`).
- `kitkatApp` subscribes with Combine sinks and binds into `ContentView`.

## Data Pattern: Weekday Counts
- Global in-memory dictionary `dayOfWeekCounts` initialized from store defaults + persisted values.
- `updateCountForCurrentDay()` does day rollover reset for current day then increments.
- Store writes full dictionary each update.

## Data Pattern: Date-Level History + Weekday Analytics
- Global in-memory dictionary `dailyHistoryCounts` mirrors persisted date-keyed history.
- `updateDailyHistoryForCurrentDay()` increments current local day key and persists pruned history.
- Pruning boundary:
  - `windowStart = startOfCurrentWeek(Monday) - 12 weeks`
  - keep entries `>= windowStart`.
- `WeekdayAverageCalculator` walks dates from `windowStart ... today`:
  - buckets Mon-Fri totals by weekday
  - only counts dates with `count > 0` as denominator occurrences
  - returns ordered rows for Monday-Friday only.
- `WeekdayAverageCalculator.productiveSummary` parses retained history entries in-window:
  - computes weekday peaks with `peak(day) = max(dayCount)`
  - returns Monday-Friday rows only
  - returns tie-safe winner set where `peak(day)` equals the global max peak.
- Workweek daily goal now derives from weekday averages:
  - `ContentView` reads `WeekdayAverageCalculator.allDayAverages(from:)` to include weekend averages from the same rolling history dataset.
  - `WorkweekGoalCalculator.dailyTarget(from:)` sums Mon-Sun average values.
  - Formula: `goal = max(5, ceil(sum(allDailyAverages) / 5.0))`.
