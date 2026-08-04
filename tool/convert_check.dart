// 常驻验证脚本:P3 阶段门真实转码验证(docs/14-测试计划.md §14.6)。
//
// 运行:dart run tool/convert_check.dart(依赖系统 ffmpeg + 夹具视频)
// 对每个夹具:打印命令快照 → 应用转码(FfmpegServiceEngine)→ CLI 直跑
// 同参命令 → SHA-256 比对(输出一致性);验证 palette.png 已清理。
// 全部通过退出 0;任一失败退出 1。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/features/converter/application/command_builder.dart';
import 'package:gif_forge/features/converter/application/ffmpeg_service_engine.dart';
import 'package:gif_forge/shared/platform/process_engine.dart';

const fixtures = [
  (
    name: 'clip_a(3s 640x360 30fps)',
    path: 'test/fixtures/videos/clip_a.mp4',
    duration: Duration(seconds: 3),
    width: 640,
    height: 360,
  ),
  (
    name: 'clip_b(3s 640x360 25fps 彩条)',
    path: 'test/fixtures/videos/clip_b.mp4',
    duration: Duration(seconds: 3),
    width: 640,
    height: 360,
  ),
  (
    name: 'clip_long(10s 320x240 24fps)',
    path: 'test/fixtures/videos/clip_long.mp4',
    duration: Duration(seconds: 10),
    width: 320,
    height: 240,
  ),
];

void main() async {
  final builder = GifCommandBuilder();
  final service = FfmpegServiceEngine(
    engine: const ProcessEngine(),
    logger: AppLogger(),
  );
  var failures = 0;

  final root = Directory.current.path;

  for (final f in fixtures) {
    final video = VideoInfo(
      path: '$root/${f.path}',
      formatName: 'mov,mp4',
      duration: f.duration,
      width: f.width,
      height: f.height,
      fps: null,
      codec: 'h264',
    );
    final appDir = await Directory.systemTemp.createTemp('convert_check_app');
    final cliDir = await Directory.systemTemp.createTemp('convert_check_cli');
    final appOut = '${appDir.path}/out.gif';
    final cliOut = '${cliDir.path}/out.gif';

    try {
      // ① 命令快照
      final commands = builder.build(
        setting: const GifSetting(),
        video: video,
        inputPath: video.path,
        workDir: appDir.path,
        outputPath: appOut,
      );
      print('命令快照 ${f.name}:');
      for (final cmd in commands) {
        print('  [${cmd.label}] ffmpeg ${cmd.args.join(' ')}');
      }

      // ② 应用转码
      final result = await service.convert(
        setting: const GifSetting(),
        video: video,
        taskId: 0,
        workDir: appDir.path,
        outputPath: appOut,
      );
      if (result.exitCode != 0 || !File(appOut).existsSync()) {
        failures++;
        print('FAIL ${f.name} → 应用转码失败 exit=${result.exitCode}');
        continue;
      }

      // ③ CLI 直跑同参命令(独立构造,与 app 目录互不依赖)
      final cliCommands = builder.build(
        setting: const GifSetting(),
        video: video,
        inputPath: video.path,
        workDir: cliDir.path,
        outputPath: cliOut,
      );
      var cliExit = 0;
      for (final cmd in cliCommands) {
        final r = await Process.run('ffmpeg', cmd.args);
        if (r.exitCode != 0) {
          cliExit = r.exitCode;
          break;
        }
      }
      if (cliExit != 0 || !File(cliOut).existsSync()) {
        failures++;
        print('FAIL ${f.name} → CLI 直跑失败 exit=$cliExit');
        continue;
      }

      // ④ SHA-256 比对
      final appHash = (await Process.run('sha256sum', [
        appOut,
      ])).stdout.toString().split(' ')[0];
      final cliHash = (await Process.run('sha256sum', [
        cliOut,
      ])).stdout.toString().split(' ')[0];
      if (appHash == cliHash) {
        print('OK   ${f.name} → SHA-256 一致 $appHash');
      } else {
        failures++;
        print('FAIL ${f.name} → 哈希不一致 app=$appHash cli=$cliHash');
      }

      // ⑤ 调色板临时文件清理
      final palette = File('${appDir.path}/palette.png');
      if (palette.existsSync()) {
        failures++;
        print('FAIL ${f.name} → palette.png 未清理');
      } else {
        print('OK   ${f.name} → palette.png 已清理');
      }
    } catch (e) {
      failures++;
      print('FAIL ${f.name} → 异常: $e');
    } finally {
      await appDir.delete(recursive: true);
      await cliDir.delete(recursive: true);
    }
  }

  print(
    failures == 0 ? 'PASS 全部通过 (${fixtures.length} 个夹具)' : 'FAILED $failures 项',
  );
  exit(failures == 0 ? 0 : 1);
}
