#!/usr/bin/env bash
# 生成 P3 集成测试夹具(彩条+运动,<1MB,提交仓库,见 docs/14-测试计划.md §14.4)。
# 依赖系统 ffmpeg;重复运行幂等(覆盖生成)。
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$BASE/test/fixtures/videos"
mkdir -p "$DIR"

# 3s 640×360 30fps(冒烟/成功路径)
ffmpeg -y -f lavfi -i "testsrc2=duration=3:size=640x360:rate=30" \
  -pix_fmt yuv420p -c:v libx264 -movflags +faststart "$DIR/clip_a.mp4" >/dev/null 2>&1

# 3s 640×360 25fps 彩条(第二段样本)
ffmpeg -y -f lavfi -i "smptebars=duration=3:size=640x360:rate=25" \
  -pix_fmt yuv420p -c:v libx264 -movflags +faststart "$DIR/clip_b.mp4" >/dev/null 2>&1

# 10s 320×240 24fps(取消测试:转码时间足够长)
ffmpeg -y -f lavfi -i "testsrc=duration=10:size=320x240:rate=24" \
  -pix_fmt yuv420p -c:v libx264 -movflags +faststart "$DIR/clip_long.mp4" >/dev/null 2>&1

# 图片→GIF 测试夹具:3 张 64×64 纯色 PNG(红/绿/蓝,见 §14.4 图片节)
IMG_DIR="$BASE/test/fixtures/images"
mkdir -p "$IMG_DIR"
ffmpeg -y -f lavfi -i "color=c=red:s=64x64" -frames:v 1 "$IMG_DIR/red.png" >/dev/null 2>&1
ffmpeg -y -f lavfi -i "color=c=green:s=64x64" -frames:v 1 "$IMG_DIR/green.png" >/dev/null 2>&1
ffmpeg -y -f lavfi -i "color=c=blue:s=64x64" -frames:v 1 "$IMG_DIR/blue.png" >/dev/null 2>&1

echo "生成完成:"
ls -la "$DIR" "$IMG_DIR"
