# Cottage

Cottage is a native macOS command panel. It is not a full Raycast replacement, is less bloated, has no paid features, and avoids messy unused features.

## Navigation

- [中文 README](../README.md)
- [Contributing Guide](CONTRIBUTING.en.md)
- [贡献指南（中文）](../CONTRIBUTING.md)
- [Action Development Guide](action-development.en.md)
- [Action 开发文档（中文）](action-development.zh.md)
- [Custom Actions Directory](#custom-actions-directory)
- [Build And Validation](#build-and-validation)

## Main Features

- Global hotkey opens a centered floating panel.
- Search apps, built-in commands, and custom actions.
- Supports four action presentation modes.
- Supports the script stdin JSON protocol.
- Runs in the background without a Dock icon.

## Custom Actions Directory

Custom actions directory:

```text
~/.config/cottage/actions/<action-id>/action.json
```

A typical action folder contains:

```text
action.json
run.py / run.sh / other script files
```

See:

- [Action Development Guide](action-development.en.md)
- [中文 Action 开发文档](action-development.zh.md)

## Build And Validation

This is an Xcode SwiftUI app. Use the unified script for linting, i18n validation, dual-architecture builds, Release export, size reporting, and app restart:

```bash
scripts/cottagepanel-build.sh
```

The script runs:

- `swiftlint lint --strict`
- i18n key validation. `CottagePanel/en.lproj/Localizable.strings` and `CottagePanel/zh-Hans.lproj/Localizable.strings` must contain the same keys.
- Debug `arm64` / `x86_64` builds.
- Release archive/export, producing Universal, arm64, and x86_64 apps and zip files.
- Chinese size report generation and exported app restart.

Useful options:

```bash
scripts/cottagepanel-build.sh --debug-only --no-restart
scripts/cottagepanel-build.sh --no-export
scripts/cottagepanel-build.sh --output Builds/CottagePanel
```

Default output directory:

```text
Builds/CottagePanel/<timestamp>/
```
