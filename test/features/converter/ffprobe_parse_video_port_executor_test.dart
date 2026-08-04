import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/exceptions/ffmpeg_missing_exception.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/exceptions/source_missing_exception.dart';
import 'package:gif_forge/features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'package:gif_forge/shared/platform/ffprobe_executor.dart';
import 'package:gif_forge/shared/platform/process_ffprobe_executor.dart';

/// [FfprobeParseVideoPort] 经 [FfprobeExecutor] 注入的测试(纯 Dart)。
///
/// 决策逻辑(assemble)既有测试已覆盖;本组聚焦 parse() 与执行器的
/// 编排与异常映射:成功汇聚、损坏/缺失分类、FFmpegMissing 透传、
/// 未预期异常兜底为 GIF_PROBE_UNREACHABLE。
void main() {
  final logger = AppLogger();

  FfprobeResult okResult(Map<dynamic, dynamic> probeJson) =>
      FfprobeResult(exitCode: 0, stderr: '', probeJson: probeJson);

  test('执行器成功 → 完整 VideoInfo(复用 fixture JSON 证明两后端同构)', () async {
    final json =
        jsonDecode(
              File(
                'test/fixtures/ffprobe/h264_640x360_29.97.json',
              ).readAsStringSync(),
            )
            as Map<dynamic, dynamic>;
    final port = FfprobeParseVideoPort(
      executor: _FakeExecutor(okResult(json)),
      logger: logger,
    );

    final info = await port.parse('/videos/demo.mp4');

    expect(info.width, 640);
    expect(info.height, 360);
    expect(info.fps, closeTo(29.97, 0.001));
    expect(info.codec, 'h264');
    expect(info.duration, const Duration(milliseconds: 10533));
  });

  test('exitCode=1 + 损坏特征 stderr → SourceBrokenException', () async {
    final port = FfprobeParseVideoPort(
      executor: _FakeExecutor(
        FfprobeResult(
          exitCode: 1,
          stderr: 'Invalid data found when processing input',
        ),
      ),
      logger: logger,
    );

    expect(
      () => port.parse('/videos/broken.mp4'),
      throwsA(isA<SourceBrokenException>()),
    );
  });

  test('exitCode=1 + 文件缺失 stderr → SourceMissingException', () async {
    final port = FfprobeParseVideoPort(
      executor: _FakeExecutor(
        FfprobeResult(exitCode: 1, stderr: 'No such file or directory'),
      ),
      logger: logger,
    );

    expect(
      () => port.parse('/videos/not_found.mp4'),
      throwsA(isA<SourceMissingException>()),
    );
  });

  test('执行器抛 FFmpegMissingException → 原样透传', () async {
    final port = FfprobeParseVideoPort(
      executor: _FakeExecutor(null, error: const FFmpegMissingException()),
      logger: logger,
    );

    expect(
      () => port.parse('/videos/x.mp4'),
      throwsA(isA<FFmpegMissingException>()),
    );
  });

  test('执行器抛任意异常 → GIF_PROBE_UNREACHABLE', () async {
    final port = FfprobeParseVideoPort(
      executor: _FakeExecutor(null, error: StateError('boom')),
      logger: logger,
    );

    expect(
      () => port.parse('/videos/x.mp4'),
      throwsA(
        isA<FilePickException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_PROBE_UNREACHABLE',
        ),
      ),
    );
  });

  test('ProcessFfprobeExecutor 二进制缺失 → FFmpegMissingException', () async {
    const executor = ProcessFfprobeExecutor(
      binaryName: 'ffprobe_definitely_not_exists',
    );

    expect(
      () => executor.run('/videos/x.mp4'),
      throwsA(isA<FFmpegMissingException>()),
    );
  });
}

class _FakeExecutor implements FfprobeExecutor {
  _FakeExecutor(this.result, {this.error});

  final FfprobeResult? result;
  final Object? error;

  @override
  Future<FfprobeResult> run(String path) async {
    if (error != null) throw error!;
    return result!;
  }
}
