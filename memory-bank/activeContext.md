# Active Context

## Current Focus
- Stabilize and clarify the day-of-week counting semantics.
- Improve weekly table readability and progress cues.

## Recent Changes (March 11, 2026)
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

## Active Decisions
- Current day is emphasized in the weekly table for fast scanning.
- `.5` values round up in average calculation.
- Counts are persisted via `DayOfTheWeekCounterStore` in `UserDefaults`.

## Open Considerations
- If product expectation changes, revisit whether `.5` should round down instead.
- Day reset only occurs when `updateCountForCurrentDay()` runs (i.e., at break completion), not at midnight.
