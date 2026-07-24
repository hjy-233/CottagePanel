# Contributing

Cottage is a personal macOS command panel. Contributions should keep it local, lightweight, and maintainable. Do not turn it into a plugin marketplace, account system, or complex platform.

## Navigation

- [中文版本](../CONTRIBUTING.md)
- [Project Scope](#project-scope)
- [Development Principles](#development-principles)
- [Local Environment](#local-environment)
- [Build And Validation](#build-and-validation)
- [Submitting Changes](#submitting-changes)
- [Action Development](#action-development)

## Project Scope

- Native macOS app built with Swift / SwiftUI.
- Runs in the background and opens a personal command panel with a hotkey.
- Built-in features should focus on frequent, local, and broadly useful actions.
- Custom actions should keep a clear file-based protocol. Do not add accounts, sync, marketplaces, or remote plugin distribution.

## Development Principles

- Keep the project buildable and runnable.
- Prefer minimal changes and reuse existing structure and utilities.
- Prefer system UI components. Add lightweight custom UI only when the system component is not suitable.
- Avoid main-thread blocking, unbounded background work, and unmanaged subprocesses.
- Treat scripts, custom actions, and file paths as security boundaries.
- When adding user-visible text, update both English and Chinese i18n.

## Local Environment

Required:

- macOS
- Xcode
- SwiftLint

Project entry:

```text
CottagePanel.xcodeproj
```

## Build And Validation

Use the unified script:

```bash
scripts/cottagepanel-build.sh
```

The script runs:

- `swiftlint lint --strict`
- i18n key validation
- Debug `arm64` / `x86_64` builds
- Release archive/export
- Universal, arm64, and x86_64 app and zip generation
- Chinese size report generation
- Exported app restart by default

Fast validation:

```bash
scripts/cottagepanel-build.sh --debug-only --no-restart
```

Validate without export:

```bash
scripts/cottagepanel-build.sh --no-export
```

## Submitting Changes

- Do not commit `Builds/`, `DerivedData/`, `.build/`, or `xcuserdata/`.
- Do not commit personal local configuration or temporary files.
- Keep each commit focused on one clear feature or fix.
- Do not bypass build issues by deleting features, returning fake data, or commenting out logic.
- If the action JSON protocol changes, update both Chinese and English Action development docs.

## Action Development

Action protocol docs:

- [中文 Action 开发文档](action-development.zh.md)
- [Action Development Guide](action-development.en.md)

Default custom actions location:

```text
~/.config/cottage/actions/<action-id>/action.json
```

Built-in actions should be implemented in Swift unless they truly need user-editable scripts.
