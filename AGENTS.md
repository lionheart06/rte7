# AGENTS Instructions for `/Users/rielkad/git/github/lionheart06/t2`

## Scope
- These instructions apply to the entire repository unless superseded by a more specific `AGENTS.md` in a subdirectory.

## General Coding Guidelines
- Keep changes focused on the user request; avoid opportunistic refactors unless asked.
- Follow Swift API Design Guidelines: descriptive names, camelCase for methods/properties, PascalCase for types, and prefer clarity over brevity.
- Avoid introducing third-party dependencies without user approval.

## Swift & macOS App Conventions
- Prefer `struct` for simple view/state types and `class` only when reference semantics are required.
- Annotate UI-updating code with `@MainActor` or ensure it runs on the main thread.
- Keep view logic lightweight; move side effects or business rules into dedicated models or utility types.

## Testing & Tooling
- When you modify production code, run the targeted unit/UI tests via `xcodebuild test -scheme kitkat -destination 'platform=macOS'` when practical.
- If formatting adjustments are needed, use `swift-format` with the repository’s existing style where available; do not add new formatter configs.

## Git Hygiene
- Do not commit or create branches; leave version control operations to the user.
- Update documentation or comments when behavior changes to prevent drift.
