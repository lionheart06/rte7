# Product Context

## Why This Exists
- Users can lose track of time while typing and skip short breaks.
- The app provides low-friction break reminders directly from the menu bar.

## Problem It Solves
- Lack of lightweight, activity-aware break nudges on macOS.
- Need for simple weekly visibility into break completion patterns.

## How It Should Work
- App starts at login/session launch and runs in the menu bar.
- Active typing moves countdown toward the next break.
- Extended idle periods reset progress to avoid reminding during inactivity.
- Break trigger opens a window and sends a notification.
- Weekly counts update and persist automatically.

## UX Goals
- Fast glanceability (countdown + idle count + weekly table).
- Minimal required interaction.
- Clear emphasis on "today" in weekly data.
- Calm visual design; avoid noisy UI.
