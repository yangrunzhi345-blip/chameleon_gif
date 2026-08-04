import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/ffmpeg_missing_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/features/converter/infrastructure/process_engine.dart';

/// [ProcessEngine] 真实二进制测试(镜像 P1 执行器模式)。
///
/// 二进制缺失路径必须验证;真实 ffmpeg 存在时跑 `-version` 冒烟
/// (存在性先探测,缺失则跳过,CI 无 ffmpeg 时全绿)。
void main() {
  const engine = ProcessEngine();

  test('二进制缺失 → FFmpegMissingException(GIF_127_ENCODE_MISSING)', () async {
    const missing = ProcessEngine(binaryName: 'ffmpeg_definitely_not_exists');
    expect(
      () => missing.convert(
        const ConvertRequest(
          command: ['-version'],
          workDir: '/tmp',
          tempFiles: [],
        ),
      ),
      throwsA(
        isA<FFmpegMissingException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_127_ENCODE_MISSING',
        ),
      ),
    );
  });

  test('真实 ffmpeg:stdout 行回调 + 退出码透传', () async {
    final hasFfmpeg = await _ffmpegExists();
    if (!hasFfmpeg) {
      markTestSkipped('系统无 ffmpeg 二进制,跳过真实执行验证');
      return;
    }

    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final result = await engine.convert(
      const ConvertRequest(
        command: ['-version'],
        workDir: '/tmp',
        tempFiles: [],
      ),
      onProgress: stdoutLines.add,
      onLog: stderrLines.add,
    );

    expect(result.exitCode, 0);
    expect(stdoutLines, isNotEmpty, reason: '-version 输出在 stdout');
    expect(stdoutLines.first, contains('ffmpeg version'));
    expect(result.cancelled, isFalse);
  });

  test('真实 ffmpeg:取消 token → 返回 cancelled 结果', () async {
    final hasFfmpeg = await _ffmpegExists();
    if (!hasFfmpeg) {
      markTestSkipped('系统无 ffmpeg 二进制,跳过真实执行验证');
      return;
    }

    final token = CancelToken();
    // 预先取消:进程启动即被终止
    token.cancel();
    final result = await engine.convert(
      const ConvertRequest(
        command: ['-i', '/dev/null', '-f', 'null', '-'],
        workDir: '/tmp',
        tempFiles: [],
      ),
      cancelToken: token,
    );
    expect(result.cancelled, isTrue);
  });
}

Future<bool> _ffmpegExists() async {
  try {
    final p = await Process.start('ffmpeg', ['-version']);
    await p.exitCode;
    return true;
  } on ProcessException {
    return false;
  }
}
