#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="CottagePanel"
SCHEME="CottagePanel"
PROJECT_PATH="CottagePanel.xcodeproj"
CONFIGURATION="Release"
OUTPUT_ROOT="Builds/CottagePanel"
RESTART_APP=1
RUN_EXPORT=1

usage() {
  cat <<'EOF'
Usage: scripts/cottagepanel-build.sh [options]

Options:
  --debug-only     Run SwiftLint, i18n check, and Debug Xcode build only.
  --no-export      Skip archive/export and only run validation builds.
  --no-restart     Do not restart the exported app.
  --output DIR     Output root directory. Default: Builds/CottagePanel
  -h, --help       Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug-only)
      CONFIGURATION="Debug"
      RUN_EXPORT=0
      ;;
    --no-export)
      RUN_EXPORT=0
      ;;
    --no-restart)
      RESTART_APP=0
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output" >&2
        exit 2
      fi
      OUTPUT_ROOT="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$ROOT_DIR/$OUTPUT_ROOT/$TIMESTAMP"
LOG_DIR="$OUT_DIR/logs"
DERIVED_DATA="$OUT_DIR/DerivedData"
mkdir -p "$LOG_DIR"

log() {
  printf '\n==> %s\n' "$1"
}

run_logged() {
  local name="$1"
  shift
  log "$name"
  "$@" 2>&1 | tee "$LOG_DIR/$name.log"
}

bytes_to_human() {
  python3 - "$1" <<'PY'
import sys

value = int(sys.argv[1])
units = ["B", "KB", "MB", "GB"]
size = float(value)
index = 0
while size >= 1024 and index < len(units) - 1:
    size /= 1024
    index += 1

print(f"{value} B" if index == 0 else f"{size:.2f} {units[index]}")
PY
}

path_logical_bytes() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.exists():
    print(0)
elif path.is_file() or path.is_symlink():
    print(path.lstat().st_size)
else:
    total = 0
    for item in path.rglob("*"):
        if item.is_file() or item.is_symlink():
            total += item.lstat().st_size
    print(total)
PY
}

check_i18n_keys() {
  python3 <<'PY'
from pathlib import Path
import re

paths = [
    Path("CottagePanel/en.lproj/Localizable.strings"),
    Path("CottagePanel/zh-Hans.lproj/Localizable.strings"),
]

key_sets = []
for path in paths:
    text = path.read_text()
    key_sets.append(set(re.findall(r'^"([^"]+)"\s*=', text, re.M)))

missing_zh = sorted(key_sets[0] - key_sets[1])
missing_en = sorted(key_sets[1] - key_sets[0])

if missing_zh or missing_en:
    print("missing zh:", missing_zh)
    print("missing en:", missing_en)
    raise SystemExit(1)

print(f"i18n keys ok: {len(key_sets[0])}")
PY
}

write_export_options() {
  cat > "$OUT_DIR/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST
}

copy_thin_app() {
  local source_app="$1"
  local arch="$2"
  local target_app="$3"
  local executable="$target_app/Contents/MacOS/$PROJECT_NAME"

  /usr/bin/ditto "$source_app" "$target_app"
  lipo -thin "$arch" "$executable" -output "$OUT_DIR/$PROJECT_NAME-$arch-bin"
  mv "$OUT_DIR/$PROJECT_NAME-$arch-bin" "$executable"
  codesign --force --sign - "$target_app" >/dev/null
}

zip_app() {
  local app_path="$1"
  local zip_path="$2"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
}

write_size_report() {
  local report_path="$OUT_DIR/size-report.zh.txt"

  {
    echo "CottagePanel 构建大小报告"
    echo "时间：$TIMESTAMP"
    echo "配置：$CONFIGURATION"
    echo "产物目录：$OUT_DIR"
    echo

    for entry in \
      "Universal App:$OUT_DIR/Export/$PROJECT_NAME.app" \
      "arm64 App:$OUT_DIR/$PROJECT_NAME-arm64.app" \
      "x86_64 App:$OUT_DIR/$PROJECT_NAME-x86_64.app" \
      "Universal Zip:$OUT_DIR/$PROJECT_NAME-universal.zip" \
      "arm64 Zip:$OUT_DIR/$PROJECT_NAME-arm64.zip" \
      "x86_64 Zip:$OUT_DIR/$PROJECT_NAME-x86_64.zip" \
      "Archive:$OUT_DIR/$PROJECT_NAME.xcarchive"; do
      local label="${entry%%:*}"
      local path="${entry#*:}"
      local bytes
      bytes="$(path_logical_bytes "$path")"
      echo "${label}：$(bytes_to_human "$bytes") ($bytes bytes)"
    done

    echo
    echo "可执行文件："
    for entry in \
      "Universal:$OUT_DIR/Export/$PROJECT_NAME.app/Contents/MacOS/$PROJECT_NAME" \
      "arm64:$OUT_DIR/$PROJECT_NAME-arm64.app/Contents/MacOS/$PROJECT_NAME" \
      "x86_64:$OUT_DIR/$PROJECT_NAME-x86_64.app/Contents/MacOS/$PROJECT_NAME"; do
      local label="${entry%%:*}"
      local path="${entry#*:}"
      local bytes
      bytes="$(path_logical_bytes "$path")"
      echo "${label}：$(bytes_to_human "$bytes") ($bytes bytes)"
      if [[ -f "$path" ]]; then
        lipo -info "$path"
      fi
    done

    echo
    echo "资源明细："
    find "$OUT_DIR/Export/$PROJECT_NAME.app/Contents" -maxdepth 3 -type f -print0 \
      | xargs -0 stat -f "%z %N" \
      | sort -rn \
      | head -30
  } | tee "$report_path"
}

log "输出目录"
printf '%s\n' "$OUT_DIR"

run_logged "swiftlint" swiftlint lint --strict

log "i18n"
check_i18n_keys | tee "$LOG_DIR/i18n.log"

run_logged "xcodebuild-debug-arm64" \
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$DERIVED_DATA" \
    build

run_logged "xcodebuild-debug-x86_64" \
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=macOS,arch=x86_64" \
    -derivedDataPath "$DERIVED_DATA" \
    build

if [[ "$RUN_EXPORT" -eq 1 ]]; then
  ARCHIVE_PATH="$OUT_DIR/$PROJECT_NAME.xcarchive"
  EXPORT_PATH="$OUT_DIR/Export"
  UNIVERSAL_APP="$EXPORT_PATH/$PROJECT_NAME.app"
  ARM_APP="$OUT_DIR/$PROJECT_NAME-arm64.app"
  X86_APP="$OUT_DIR/$PROJECT_NAME-x86_64.app"

  write_export_options

  run_logged "xcodebuild-archive-universal" \
    xcodebuild archive \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination "generic/platform=macOS" \
      -archivePath "$ARCHIVE_PATH" \
      -derivedDataPath "$DERIVED_DATA"

  run_logged "xcodebuild-export-universal" \
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportPath "$EXPORT_PATH" \
      -exportOptionsPlist "$OUT_DIR/ExportOptions.plist"

  log "拆分 arm64/x86_64 App"
  copy_thin_app "$UNIVERSAL_APP" "arm64" "$ARM_APP"
  copy_thin_app "$UNIVERSAL_APP" "x86_64" "$X86_APP"

  log "压缩 App"
  zip_app "$UNIVERSAL_APP" "$OUT_DIR/$PROJECT_NAME-universal.zip"
  zip_app "$ARM_APP" "$OUT_DIR/$PROJECT_NAME-arm64.zip"
  zip_app "$X86_APP" "$OUT_DIR/$PROJECT_NAME-x86_64.zip"

  log "大小报告"
  write_size_report

  if [[ "$RESTART_APP" -eq 1 ]]; then
    log "重启导出 App"
    pkill -x "$PROJECT_NAME" || true
    open "$UNIVERSAL_APP"
    sleep 1
    pgrep -ax "$PROJECT_NAME" || true
  fi
else
  log "跳过 archive/export"
fi

log "完成"
printf '输出目录：%s\n' "$OUT_DIR"
