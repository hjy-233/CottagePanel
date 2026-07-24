# Cottage Action Development Guide

This document describes Cottage custom action API v1.

## Navigation

- [中文版本](action-development.zh.md)
- [Project README](README.en.md)
- [Manifest](#manifest)
- [Input Protocol](#input-protocol)
- [Dropped Input](#dropped-input)
- [Output Protocol](#output-protocol)
- [Menus And Shortcuts](#menus-and-shortcuts)
- [Forms](#forms)
- [Navigation](#navigation)
- [Validation Rules](#validation-rules)

## Folder Layout

```text
~/.config/cottage/actions/my-action/
  action.json
  run.py
  details.py
```

Scripts run with the action folder as the current directory. `script.command` and `navigation.command` are resolved relative to that folder.

## Manifest

Example:

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

### Core Fields

- `apiVersion`: currently `1`; omitted values are treated as v1.
- `id`: action ID, only `[A-Za-z0-9_-]`.
- `title` / `subtitle`: main and secondary labels.
- `symbolName`: SF Symbol fallback name.
- `icon`: optional image file inside the action directory, for example `icon.png` or `assets/icon.png`; relative paths only.
- `tags`: searchable tags.
- `type`: `script`: run a script, `shell`: execute shell, `openApp`: open `.app`, `shortcut`: simulate a shortcut, `url`: open URL, `open`: open a file.
- `presentation`: `direct`: run directly, `panel`: open a panel, `popup`: open a prompt, `form`: open a form.
- `trigger`: `manual`: run after the user presses Enter, or `live`: run whenever user input changes.

### Required Fields By Type

- `script` / `shell`: `command`; for `script`, the command file must exist inside the action directory and cannot point outside it, including through symlinks.
- `open` / `openApp`: `path`
- `url`: `url`
- `shortcut`: `shortcutName`

## Input Protocol

Cottage writes a JSON payload to the script stdin:

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

Environment variable channel (not recommended):

- `COTTAGE_QUERY`
- `COTTAGE_ACTION_DIR`
- `COTTAGE_LOCALE`
- `COTTAGE_ACCESSORY_<KEY>`
- `COTTAGE_FORM_<FIELD_ID>`
- `COTTAGE_RESULT_ID`, `COTTAGE_RESULT_TITLE`, `COTTAGE_RESULT_TEXT`, etc.

Important information:

- `password` and `textarea` fields are sent through stdin JSON only, not `COTTAGE_FORM_*`.
- Form field IDs are uppercased for env vars, and `-` becomes `_`.
- `my-field` and `my_field` collide after normalization and invalidate the action.

### Dropped Input

`input` can declare whether the action accepts dropped content:

```json
"input": {
  "acceptsDroppedText": true,
  "acceptsDroppedFiles": true,
  "acceptedContentTypes": ["public.text", "public.file-url"]
}
```

- `acceptsDroppedText`: writes dropped text into `query`.
- `acceptsDroppedFiles`: writes dropped file paths into `query`, separated by newlines.
- `acceptedContentTypes`: developer-facing declaration for docs and future validation; v1 currently handles text and file URLs only.
- `form.fields[].acceptsDroppedContent`: controls whether a form field accepts dropped content; `text`, `textarea`, `file`, and `folder` default to `true`.
- Dropped text fills the first accepting `text` / `textarea` field; dropped files fill the first accepting `file` / `folder` field.
- `password` fields do not accept drops by default and are not saved in query history.

## Output Protocol

`panel` / `form` action stdout is JSON Lines. Each line is one result object.

Example:

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

### Accessories

- Only the first 3 accessories are shown.
- `style`: `default`, `secondary`, `success`, `warning`, `error`.
- Provide at least `text` or `symbolName`.

### Metadata

- `type`: `text`, `code`, `link`.
- `link` requires `url`.
- Allowed URL schemes: `http`, `https`, `file`.
- Metadata is not used by the default copy behavior.

## Menus And Shortcuts

Action menu:

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

Result menu:

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

Rules:

- `children` supports recursion up to depth 5.
- Clicking an item with `children` opens a submenu and does not run the parent action.
- Children do not inherit parent `confirm`, `postRun`, or `shortcut`.
- Empty `children` behaves like a normal action.

## Search Accessory

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

Rules:

- `defaultValue` must exist in `items`.
- Cottage generates the env var name, for example `COTTAGE_ACCESSORY_FILTER`.
- The accessory value is isolated per panel page lifecycle.
- Live actions rerun when the accessory changes.

## Forms

Use `presentation: "form"` for a form page:

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

Field types:

- `text`
- `password`
- `textarea`
- `checkbox`
- `select`
- `file`
- `folder`

Submit behavior:

- Shows running state while executing.
- Keeps the form visible after success.
- Shows results below the form and in the right preview pane.
- `postRun.onSuccess` controls follow-up behavior.

## Navigation

A result can push a child page:

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

Legacy shorthand:

```json
{ "navigationCommand": "details.py" }
```

The child page stdin payload includes:

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

Rules:

- Maximum navigation depth is 8.
- `Esc`: depth > 0 pops; depth = 0 exits the action; from the main panel, `Esc` closes Cottage.
- Pop restores query, accessory, form values, results, selected result, and preview.

## Menu Bar

```json
"menuBar": {
  "enabled": true,
  "title": "Example",
  "symbolName": "function",
  "order": 10
}
```

Rules:

- Items appear only inside the Cottage status menu; they do not create separate menu bar icons.
- `direct` actions run immediately.
- `panel`, `form`, and `popup` actions open the Cottage panel.
- Reload Actions refreshes the status menu immediately.

## Validation Rules

Invalid actions are skipped and logged via NSLog:

- `apiVersion` must be `1` (may be extended later).
- IDs must use `[A-Za-z0-9_-]`.
- `searchAccessory.defaultValue` must exist.
- Normalized form field env keys must not collide.
- Select defaults must exist in `items`.
- Submenu max depth is 5.
- Required fields for each action type must exist.
