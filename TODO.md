# kitkat TODO

## P0 - Data correctness

- [ ] Replace global mutable weekday state with an injected service/model.
  - Current globals:
    - `dayOfWeekCounts` in `kitkat/Model/CountDownTimer.swift:95`
    - `g_dayOfWeek` in `kitkat/Model/CountDownTimer.swift:112`
  - Target: move counting + rollover into a dedicated type with explicit state and tests.

- [ ] Fix same-day reset risk on app relaunch.
  - Current behavior: first `updateCountForCurrentDay()` call can reset today to `0` when `g_dayOfWeek` is empty.
  - Relevant code: `kitkat/Model/CountDownTimer.swift:115-130`
  - Target: persist/derive last-updated day robustly, or make rollover logic idempotent across launches.

## P1 - Runtime robustness

- [ ] Fix event monitor lifecycle handling.
  - Current issue: local monitor token from `NSEvent.addLocalMonitorForEvents` is not retained/removed.
  - Relevant code: `kitkat/Model/GlobalEventMonitor.swift:30-34`, `46-50`
  - Target: store both local/global monitor tokens and remove both in `stop()`.

- [ ] Remove `NSScreen.main!` force unwrap.
  - Current code: `kitkat/kitkatApp.swift:102`
  - Target: handle nil screen safely with fallback window sizing.

## P2 - Cleanup / maintainability

- [ ] Remove or isolate template/demo SwiftData code from production path.
  - Relevant code:
    - `ContentView2` in `kitkat/ContentView.swift:343-398`
    - `Item` model in `kitkat/Item.swift:11-17`
  - Target: delete unused sample code or move to a dedicated sandbox target.

- [ ] Improve project README for onboarding.
  - Current file is placeholder: `README.md`
  - Target: include app purpose, architecture overview, build/test commands, and known environment caveats.

## Test coverage backlog (supports items above)

- [ ] Add unit tests for `CountDownTimer` state transitions, idle reset, and break trigger path.
- [ ] Add unit tests for weekday rollover/count update behavior.
- [ ] Add tests for `DayOfTheWeekCounterStore` load/save merge behavior.
- [ ] Add tests (or adapter-based tests) for `GlobalEventMonitor` lifecycle behavior.
- [ ] Add tests for `QuoteViewModel` success/failure message updates.
