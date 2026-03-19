# System Patterns

## Architecture Overview
- Entry point: `kitkatApp` (`@main` SwiftUI App).
- Coordination: `AppDelegate` owns runtime services and published app state.
- Timer engine: `CountDownTimer` drives countdown + break trigger.
- Input signal: `GlobalEventMonitor` marks user activity via keyboard events.
- Persistence: `DayOfTheWeekCounterStore` reads/writes weekday counts from `UserDefaults`.
- Goal calculation: `WorkweekGoalCalculator` computes the displayed daily target.
- UI: `ContentView` renders timer, idle count, weekly table, and average/goal metric.

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
- published state is pushed to SwiftUI.

## State Propagation Pattern
- `AppDelegate` exposes `@Published` properties (`menuText`, `dayOfTheWeekCounts`, `remainingSeconds`, `idleCount`).
- `kitkatApp` subscribes with Combine sinks and binds into `ContentView`.

## Data Pattern: Weekday Counts
- Global in-memory dictionary `dayOfWeekCounts` initialized from store defaults + persisted values.
- `updateCountForCurrentDay()` does day rollover reset for current day then increments.
- Store writes full dictionary each update.
- Daily goal target derives from counts via `WorkweekGoalCalculator.dailyTarget(from:)` using `max(5, ceil(totalAcrossAllDays / 5.0))`.
