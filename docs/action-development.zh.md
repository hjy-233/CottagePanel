# Cottage Action 开发文档

本文档描述 Cottage 自定义 action v1 协议。

## 跳转

- [English Version](action-development.en.md)
- [项目 README](../README.md)
- [Manifest](#manifest)
- [输入协议](#输入协议)
- [输出协议](#输出协议)
- [菜单与快捷键](#菜单与快捷键)
- [表单](#表单)
- [Navigation](#navigation)
- [校验规则](#校验规则)

## 目录结构

```text
~/.config/cottage/actions/my-action/
  action.json
  run.py
  details.py
```

脚本相对 action 目录执行，`script` 的 `command` 和 `navigation.command` 也相对该目录解析。

## Manifest

示例：

```json
{
  "apiVersion": 1,
  "id": "example",
  "title": "Example",
  "subtitle": "Example action",
  "symbolName": "sparkle",
  "icon": "icon.png",
  "tags": ["example"],
  "type": "script",
  "command": "run.py",
  "presentation": "panel",
  "trigger": "manual"
}
```

### 基础字段

- `apiVersion`: 目前为 `1`；缺省时按 v1 处理。
- `id`: action ID，只允许 `[A-Za-z0-9_-]`。
- `title` / `subtitle`: 主标题和副标题。
- `symbolName`: SF Symbol fallback 名称。
- `icon`: 可选，action 目录内的图片文件，例如 `icon.png` 或 `assets/icon.png`；只支持相对路径。
- `tags`: 搜索标签。
- `type`: `script`: 运行脚本、`shell`: 执行shell、`openApp`: 打开 .app、`shortcut`: 模拟快捷键、`url`: 打开 URL、`open`: 打开文件。
- `presentation`: `direct`: 直接执行、`panel`: 打开一个面板、`popup`: 打开一个提示框、`form`: 打开一个表单。
- `trigger`: `manual`: 用户按下 enter 后执行 或 `live`: 实时执行（只要用户输入变化就执行）。

### type 必填字段

- `script` / `shell`: `command`；`script` 的命令文件必须存在于 action 目录内，不能通过相对路径或软链接指向目录外。
- `open` / `openApp`: `path`
- `url`: `url`
- `shortcut`: `shortcutName`

## 输入协议

Cottage 会把完整输入写入脚本 stdin，格式是 JSON：

```json
{
  "apiVersion": 1,
  "query": "search text",
  "form": {
    "query": "hello",
    "password": "secret"
  },
  "accessory": {
    "filter": "all"
  },
  "result": null,
  "navigation": null
}
```

环境变量通道 (不推荐)：

- `COTTAGE_QUERY`
- `COTTAGE_ACTION_DIR`
- `COTTAGE_LOCALE`
- `COTTAGE_ACCESSORY_<KEY>`
- `COTTAGE_FORM_<FIELD_ID>`
- `COTTAGE_RESULT_ID`、`COTTAGE_RESULT_TITLE`、`COTTAGE_RESULT_TEXT` 等

重要信息：

- `password` 和 `textarea` 默认只通过 stdin JSON 传递，不注入 `COTTAGE_FORM_*`。
- form field ID 注入环境变量时会转大写，并把 `-` 转成 `_`。
- `my-field` 和 `my_field` 规范化后冲突，会导致 action 校验失败。

## 输出协议

`panel` / `form` action 的 stdout 是 JSON Lines，每行一个 result object 。

例子:

```json
{
  "apiVersion": 1,
  "id": "result-1",
  "title": "Result",
  "subtitle": "Subtitle",
  "text": "Preview text",
  "tags": ["result"],
  "url": "https://example.com",
  "path": "/tmp/example",
  "accessories": [
    { "text": "Ready", "symbolName": "checkmark.circle", "style": "success" }
  ],
  "metadata": [
    { "label": "Path", "value": "/tmp/example", "type": "code" },
    { "label": "Docs", "value": "Open", "url": "https://example.com", "type": "link" }
  ]
}
```

### accessories

- 最多显示前 3 个。
- `style`: `default`、`secondary`、`success`、`warning`、`error`。
- `text` 和 `symbolName` 至少应该提供一个。

### metadata

- `type`: `text`、`code`、`link`。
- `link` 必须提供 `url`。
- 只允许 `http`、`https`、`file` URL scheme。
- metadata 不参与默认复制。

## 菜单与快捷键

Action 菜单：

```json
"shortcuts": [
  {
    "id": "more",
    "title": "More",
    "symbolName": "ellipsis",
    "type": "shell",
    "children": [
      {
        "id": "copy",
        "title": "Copy",
        "shortcut": "cmd+shift+c",
        "type": "shell",
        "command": "printf 'copied' | pbcopy"
      }
    ]
  }
]
```

Result 菜单：

```json
"resultActions": [
  {
    "id": "copy-result",
    "title": "Copy Result",
    "shortcut": "cmd+shift+c",
    "type": "shell",
    "operation": "copyResultText"
  }
]
```

规则：

- `children` 支持递归，最大深度 5。
- 有 `children` 的父项点击时进入 submenu，不执行父 action。
- 子项不继承父项的 `confirm`、`postRun`、`shortcut`。
- 空 `children` 视为普通 action。

## 搜索栏选项

```json
"searchAccessory": {
  "id": "filter",
  "envKey": "filter",
  "defaultValue": "all",
  "items": [
    { "id": "all", "title": "All" },
    { "id": "recent", "title": "Recent" }
  ]
}
```

规则：

- `defaultValue` 必须存在于 `items`。
- 环境变量名由 Cottage 生成：`COTTAGE_ACCESSORY_FILTER`。
- accessory 状态在当前页面生命周期内独立保存。
- live action 切换 accessory 后会重新执行。

## 表单

`presentation: "form"` 使用表单页面：

```json
"form": {
  "fields": [
    {
      "id": "query",
      "type": "text",
      "title": "Query",
      "placeholder": "Text...",
      "required": true
    },
    {
      "id": "mode",
      "type": "select",
      "title": "Mode",
      "defaultValue": "fast",
      "items": [
        { "id": "fast", "title": "Fast" },
        { "id": "full", "title": "Full" }
      ]
    }
  ]
}
```

字段类型：

- `text`
- `password`
- `textarea`
- `checkbox`
- `select`
- `file`
- `folder`

提交行为：

- 提交时显示 running。
- 成功后保留表单。
- 结果显示在表单下方列表和右侧 preview。
- 后续行为由 `postRun.onSuccess` 控制。

## Navigation

Result 可以进入子页面：

```json
{
  "id": "details",
  "title": "Details",
  "presentation": "panel",
  "navigation": {
    "command": "details.py",
    "title": "Details",
    "trigger": "manual",
    "searchPlaceholder": "Search details..."
  }
}
```

兼容简写：

```json
{ "navigationCommand": "details.py" }
```

子页面 stdin JSON 会包含：

```json
{
  "result": {
    "id": "details",
    "title": "Details",
    "text": "..."
  },
  "navigation": {
    "sourceActionId": "example",
    "sourceResultId": "details",
    "depth": 1
  }
}
```

规则：

- 最大 navigation 深度为 8。
- `Esc`: depth > 0 时 pop；depth = 0 时退出 action；主面板再次 `Esc` 关闭 Cottage。
- pop 后恢复 query、accessory、form、results、selected result 和 preview。

## Menu Bar

```json
"menuBar": {
  "enabled": true,
  "title": "Example",
  "symbolName": "function",
  "order": 10
}
```

规则：

- 只显示在 Cottage 状态栏菜单中，不创建独立状态栏图标。
- `direct` action 点击后直接执行。
- `panel` / `form` / `popup` action 点击后打开 Cottage panel。
- Reload Actions 后菜单立即刷新。

## 校验规则

Action 不合法会被跳过，并写入 NSLog：

- `apiVersion` 必须为 `1`。(以后可能拓展)
- ID 只能使用 `[A-Za-z0-9_-]`。
- `searchAccessory.defaultValue` 必须存在。
- form field ID 规范化后不能冲突。
- select 默认值必须存在于 items。
- submenu 最大深度为 5。
- 必填字段缺失时 action 禁用。
