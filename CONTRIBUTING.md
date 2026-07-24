# 贡献指南

Cottage 是个人 macOS 操作面板，优先服务本地、轻量、可维护的使用体验。贡献时请避免把它做成插件市场、账号系统或复杂平台。

## 跳转

- [English Version](docs/CONTRIBUTING.en.md)
- [项目定位](#项目定位)
- [开发原则](#开发原则)
- [本地环境](#本地环境)
- [构建与验证](#构建与验证)
- [提交改动](#提交改动)
- [Action 开发](#action-开发)

## 项目定位

- macOS 原生 Swift / SwiftUI 应用。
- 常驻后台，通过快捷键打开个人操作面板。
- 内置功能优先覆盖高频、本地、通用动作。
- 自定义 action 保持文件协议清晰，不引入账号、同步、商店、远程插件分发。

## 开发原则

- 保证代码可编译、可运行。
- 优先最小改动，复用现有结构和工具。
- UI 优先使用系统组件；没有合适系统组件时再做轻量自定义。
- 避免主线程阻塞、无界后台任务和不可控子进程。
- 涉及脚本、自定义 action、文件路径时必须考虑安全边界。
- 新增用户可见文案时，同步更新中英文 i18n。

## 本地环境

需要：

- macOS
- Xcode
- SwiftLint

项目入口：

```text
CottagePanel.xcodeproj
```

## 构建与验证

统一使用脚本：

```bash
scripts/cottagepanel-build.sh
```

脚本会执行：

- `swiftlint lint --strict`
- i18n key 检查
- Debug `arm64` / `x86_64` 构建
- Release archive/export
- Universal、arm64、x86_64 App 和 zip 产物生成
- 中文大小报告生成
- 默认重启导出的 App

快速验证：

```bash
scripts/cottagepanel-build.sh --debug-only --no-restart
```

只验证不导出：

```bash
scripts/cottagepanel-build.sh --no-export
```

## 提交改动

- 不提交 `Builds/`、`DerivedData/`、`.build/`、`xcuserdata/`。
- 不提交本地个人配置和临时文件。
- 一个提交尽量对应一个明确功能或修复。
- 不用删除功能、返回假数据、注释逻辑来绕过构建问题。
- 如果修改 action JSON 协议，同时更新中英文 Action 开发文档。

## Action 开发

Action 协议文档：

- [中文 Action 开发文档](docs/action-development.zh.md)
- [English Action Development Guide](docs/action-development.en.md)

自定义 actions 默认位置：

```text
~/.config/cottage/actions/<action-id>/action.json
```

内置 action 应该放进 Swift 代码，除非确实需要用户可编辑脚本。
