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

- [ ] Extract a shared settings surface for break-window widgets.
  - Current pattern: each widget adds its own row to `ContentView` with a bespoke view + model pair (`kitkat/WeatherLocationSettingsView.swift`, `kitkat/Model/WeatherLocationSettingsModel.swift`; the stock tile adds the same shape).
  - Repeated pieces: an `@AppStorage`-bound field, a lookup-on-submit that validates the value against the data source, and an idle/checking/found/failed status label.
  - Target: one settings panel (a `Settings` scene or a single `GroupBox`) built from a reusable validated-field row and a shared status view, where each widget contributes only its storage keys and a validation closure.

- [ ] Move the Finnhub API key from UserDefaults to the Keychain.
  - Current: `StockSettingsStore.apiKeyKey` stores the key in the sandboxed app defaults (`kitkat/Utils/StockSettingsStore.swift`).
  - Blocker: the app is ad-hoc signed, and Keychain access is tied to the code signature, so every rebuild would prompt or lose the item.
  - Target: once a development team signs the build, store the key with `SecItem` and keep the same `StockSettingsStore` API.

## Test coverage backlog (supports items above)

- [ ] Add unit tests for `CountDownTimer` state transitions, idle reset, and break trigger path.
- [ ] Add unit tests for weekday rollover/count update behavior.
- [ ] Add tests for `DayOfTheWeekCounterStore` load/save merge behavior.
- [ ] Add tests (or adapter-based tests) for `GlobalEventMonitor` lifecycle behavior.
- [ ] Add tests for `QuoteViewModel` success/failure message updates.
