#!/usr/bin/env bash
# 中文路径 workaround:项目根目录含中文,flutter analyze 的 analysis server 会抛
# FormatException 崩溃(已实证)。本脚本将源码同步到 ASCII 路径 /tmp/gifforge_copy,
# analyze 一律在该副本执行;flutter test 已验证可在原目录直接跑。
#
# 用法:
#   bash tool/ascii_sync.sh            # 同步
#   cd /tmp/gifforge_copy && flutter pub get && flutter analyze
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST=/tmp/gifforge_copy
EXCLUDES=(--exclude .dart_tool --exclude build --exclude .git)

mkdir -p "$DST"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${EXCLUDES[@]}" "$SRC/" "$DST/"
else
  # 无 rsync 时全量复制;副本 .dart_tool 会被重建,需重新 flutter pub get
  rm -rf "$DST"
  cp -a "$SRC" "$DST"
  echo "WARN: 未检测到 rsync,已全量复制。副本需重新执行 flutter pub get。"
fi
echo "synced: $SRC -> $DST"
