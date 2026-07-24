# Cottage

Cottage 是一个 macOS 原生操作面板。不是 Raycast 的完整替代品，不那么臃肿，没有付费功能，没有乱七八糟的无用功能

## 跳转

- [English README](docs/README.en.md)
- [贡献指南](CONTRIBUTING.md)
- [Contributing Guide（English）](docs/CONTRIBUTING.en.md)
- [Action 开发文档（中文）](docs/action-development.zh.md)
- [Action Development Guide（English）](docs/action-development.en.md)
- [自定义 Actions 目录](#自定义-actions-目录)
- [构建与验证](#构建与验证)

## 主要功能

- 全局快捷键唤起居中浮动面板。
- 搜索应用、内置动作和自定义 actions。
- 支持四种 action 展示方式。
- 支持脚本 stdin JSON 协议。
- 常驻后台，不显示 Dock 图标。

## 自定义 Actions 目录

自定义 actions 目录：

```text
~/.config/cottage/actions/<action-id>/action.json
```

每个 action 目录通常包含：

```text
action.json
run.py / run.sh / 其他脚本文件
```

Action 开发协议见：

- [中文文档](docs/action-development.zh.md)
- [English guide](docs/action-development.en.md)

## 构建与验证

项目是 Xcode SwiftUI App。现在统一使用脚本做 lint、i18n、双架构构建、Release 导出、大小报告和重启：

```bash
scripts/cottagepanel-build.sh
```

脚本会执行：

- `swiftlint lint --strict`
- i18n key 检查，要求 `CottagePanel/en.lproj/Localizable.strings` 和 `CottagePanel/zh-Hans.lproj/Localizable.strings` key 一致。
- Debug `arm64` / `x86_64` 构建。
- Release archive/export，生成 Universal、arm64、x86_64 三份 App 和 zip。
- 生成中文大小报告并重启导出的 App。

常用参数：

```bash
scripts/cottagepanel-build.sh --debug-only --no-restart
scripts/cottagepanel-build.sh --no-export
scripts/cottagepanel-build.sh --output Builds/CottagePanel
```

默认产物目录：

```text
Builds/CottagePanel/<timestamp>/
```
