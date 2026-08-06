// 常驻验证脚本:图片模式 + 播放速度真实转码验证(依赖系统 ffmpeg)。
//
// 运行:dart run tool/convert_check_images.dart
// 用 lavfi 生成两张测试图 → GifCommandBuilder.buildFromImages(speed=2)
// → CLI 直跑 palette/encode 遍 → 断言 exit 0 + 产物存在。
// 回归锁:BUG 修复前 concat 带 [vout] 标签会致 setpts 输入悬空、
// 滤镜图绑定失败(exit 234),本脚本为该项提供真实转码门。
// 全部通过退出 0;任一失败退出 1。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/converter/application/command_builder.dart';

void main() async {
  final builder = GifCommandBuilder();
  final workDir = await Directory.systemTemp.createTemp('convert_check_img');
  final outPath = '${workDir.path}/out.gif';
  final img1 = '${workDir.path}/i1.png';
  final img2 = '${workDir.path}/i2.png';
  var failures = 0;

  try {
    // ① lavfi 生成两张测试图(无需外部夹具)
    for (final (color, path) in [('red', img1), ('blue', img2)]) {
      final r = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=$color:s=320x240:d=0.1',
        '-frames:v',
        '1',
        '-y',
        path,
      ]);
      if (r.exitCode != 0 || !File(path).existsSync()) {
        failures++;
        print('FAIL 测试图生成失败($color) exit=${r.exitCode}');
        return;
      }
    }
    print('OK   测试图已生成');

    // ② 命令快照(speed=2:帧数不变、总时长减半)
    const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 2);
    const source = ImageGifSource(
      paths: ['i1.png', 'i2.png'],
      width: 320,
      height: 240,
    );
    final commands = builder.buildFromImages(
      setting: setting,
      source: source,
      workDir: workDir.path,
      outputPath: outPath,
    );
    print('命令快照(2 图 × 1s ÷ 2 倍速):');
    for (final cmd in commands) {
      print('  [${cmd.label}] ffmpeg ${cmd.args.join(' ')}');
    }

    // ③ CLI 直跑:需把构造中的相对路径替换为真实绝对路径
    var cliExit = 0;
    for (final cmd in commands) {
      final args = [
        for (final a in cmd.args)
          a == 'i1.png' ? img1 : (a == 'i2.png' ? img2 : a),
      ];
      final r = await Process.run('ffmpeg', args);
      if (r.exitCode != 0) {
        cliExit = r.exitCode;
        print('FAIL [${cmd.label}] ffmpeg exit=${r.exitCode}');
        print('stderr: ${r.stderr}');
        break;
      }
    }
    if (cliExit != 0 || !File(outPath).existsSync()) {
      failures++;
      print('FAIL 图片模式 speed=2 转码失败 exit=$cliExit');
      return;
    }

    // ④ 产物时长 ≈ 源总时长 ÷ speed(2s ÷ 2 = 1s,GIF 帧延迟量化 ±0.2s)
    final dur = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'csv=p=0',
      outPath,
    ]);
    final seconds = double.tryParse(dur.stdout.toString().trim());
    final expected = 2 / 2; // Σ每图时长 ÷ speed
    if (seconds == null || (seconds - expected).abs() > 0.2) {
      failures++;
      print('FAIL 产物时长 ${seconds}s,预期 ≈${expected}s');
      return;
    }
    print('OK   产物时长 ${seconds}s(预期 ≈${expected}s)');
    // 注:palette.png 清理为应用层行为(convert_check.dart 已覆盖),
    // 本脚本纯 CLI 直跑不检查。
  } catch (e) {
    failures++;
    print('FAIL 异常: $e');
  } finally {
    await workDir.delete(recursive: true);
  }

  print(failures == 0 ? 'PASS 图片模式速度转码全部通过' : 'FAILED $failures 项');
  exit(failures == 0 ? 0 : 1);
}
