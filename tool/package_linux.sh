#!/usr/bin/env bash
# Linux 打包脚本(P9;CI 与本地共用,保证产物一致性)。
#
# 输入:flutter build linux --release 产物(build/linux/x64/release/bundle);
# 输出:dist/package/ 下 AppImage + deb。与本地已验证流程一致
# (tool/appimage AppDir 结构 + appimagetool;deb 依赖系统 ffmpeg)。
#
# 用法:
#   bash tool/package_linux.sh [版本号]     # 版本默认取 pubspec version(去 +build)
#   APPIMAGE_TOOL=/path/to/appimagetool bash tool/package_linux.sh  # 指定工具
#
# 依赖:appimagetool(AppImage);dpkg-deb(deb,缺失时跳过并告警)。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)}"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
APPIMAGE_TOOL="${APPIMAGE_TOOL:-appimagetool}"
OUT="$ROOT/dist/package"
APPDIR="$OUT/AppDir"
ICON="$ROOT/linux/runner/resources/app_icon.png"

if [ ! -x "$BUNDLE/chameleon_gif" ]; then
  echo "错误:未找到 release bundle,请先执行 flutter build linux --release" >&2
  exit 1
fi

# 清理范围限定为本脚本自建目录与同名产物(不触碰 dist/package 内其他文件)
rm -f "$OUT/Chameleon Gif-$VERSION.AppImage" "$OUT/chameleon-gif_${VERSION}_amd64.deb"
rm -rf "$APPDIR" "$OUT/deb-root"
mkdir -p "$APPDIR/usr/bin"

echo "==> 组装 AppDir(bundle 复制)"
cp -r "$BUNDLE/chameleon_gif" "$BUNDLE/data" "$BUNDLE/lib" "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/chameleon_gif"

echo "==> 生成 .desktop / AppRun / 图标"
cp "$ICON" "$APPDIR/chameleon_gif.png"
cat > "$APPDIR/chameleon_gif.desktop" << 'EOF'
[Desktop Entry]
Name=Chameleon Gif
GenericName=MP4 转 GIF 工具
Comment=跨平台 MP4/多图片 转 GIF 工具
Exec=chameleon_gif
Icon=chameleon_gif
Terminal=false
Type=Application
Categories=Utility;Graphics;
StartupNotify=true
Keywords=gif;mp4;converter;
EOF
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
exec "$(dirname "$0")/usr/bin/chameleon_gif" "$@"
EOF
chmod +x "$APPDIR/AppRun"
ln -sf chameleon_gif.png "$APPDIR/.DirIcon"

echo "==> 打包 AppImage(版本 $VERSION)"
"$APPIMAGE_TOOL" --appimage-extract-and-run "$APPDIR" "$OUT/Chameleon Gif-$VERSION.AppImage"

# ---- deb(依赖系统 ffmpeg,缺失时 dpkg-deb 不在则跳过) ----
if command -v dpkg-deb >/dev/null 2>&1; then
  echo "==> 打包 deb(版本 $VERSION)"
  DEB="$OUT/deb-root"
  mkdir -p "$DEB/usr/bin" "$DEB/usr/share/applications" \
    "$DEB/usr/share/icons/hicolor/256x256/apps" "$DEB/DEBIAN"
  cp -r "$BUNDLE/chameleon_gif" "$BUNDLE/data" "$BUNDLE/lib" "$DEB/usr/bin/"
  chmod +x "$DEB/usr/bin/chameleon_gif"
  cp "$ICON" "$DEB/usr/share/icons/hicolor/256x256/apps/chameleon-gif.png"
  cp "$APPDIR/chameleon_gif.desktop" "$DEB/usr/share/applications/chameleon-gif.desktop"
  cat > "$DEB/DEBIAN/control" << EOF
Package: chameleon-gif
Version: $VERSION
Section: video
Priority: optional
Architecture: amd64
Installed-Size: $(du -sk "$DEB/usr" | awk '{print $1}')
Maintainer: Chameleon Gif Developers <dev@chameleongif.local>
Depends: ffmpeg
Description: 跨平台 MP4/多图片 转 GIF 工具
 AppImage/deb 分发的 Chameleon Gif(桌面依赖系统 ffmpeg,缺失时应用提示).
EOF
  dpkg-deb --build --root-owner-group "$DEB" "$OUT/chameleon-gif_${VERSION}_amd64.deb" >/dev/null
  rm -rf "$DEB"
else
  echo "警告:未检测到 dpkg-deb,跳过 deb(仅产出 AppImage)" >&2
fi

echo "==> 完成:dist/package/"
ls -la "$OUT" | grep -v AppDir
