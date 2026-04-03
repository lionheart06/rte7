# Project Brief

## Project
- Name: `kitkat`
- Type: macOS SwiftUI menu bar app
- Goal: Encourage regular breaks while the user is actively typing.

## Core Behavior
- The app shows a countdown in the macOS menu bar.
- Keyboard activity advances the countdown toward a break.
- When a break is due, the app posts a local notification and opens a break window.
- A weekly table tracks break counts by weekday and persists them in `UserDefaults`.

## Current Product Scope
- Countdown timer and idle tracking.
- Keyboard event monitoring (local + global monitors).
- Break modal window with quote-of-the-day fetch.
- Day-of-week count persistence and visualization.
- Workweek average goal metric derived from all-day averages (Mon-Sun, 13-week history) with a fixed divisor of `5` displayed in UI.

## Constraints
- Keep implementation lightweight and native (Swift/SwiftUI/AppKit interop).
- Avoid adding third-party dependencies.
