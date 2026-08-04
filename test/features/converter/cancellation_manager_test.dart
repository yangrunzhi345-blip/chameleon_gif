import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/shared/platform/cancellation_manager.dart';

/// [terminateProcess] 与 [CancellationManager] 测试(docs/08 §8.3.6)。
void main() {
  group('terminateProcess(② kill → ③ 等 3s → ④ 强杀)', () {
    test('kill 后进程退出 → 不强杀', () async {
      final handle = FakeProcessHandle();
      handle.exitsOnKill = true;

      await terminateProcess(handle, delay: (_) async {});

      expect(handle.kills, [false], reason: '仅一次普通 kill');
      expect(handle.hasExited, isTrue);
    });

    test('kill 后 3s 未退出 → kill(force)', () async {
      final handle = FakeProcessHandle();
      handle.exitsOnKill = false; // 忽略普通 kill,保持存活

      await terminateProcess(handle, delay: (_) async {});

      expect(handle.kills, contains(true), reason: '超时后强杀');
      expect(handle.hasExited, isTrue, reason: '强杀后退出');
    });

    test('已退出进程直接返回(幂等)', () async {
      final handle = FakeProcessHandle()..exited = true;

      await terminateProcess(handle, delay: (_) async {});

      expect(handle.kills, isEmpty);
    });
  });

  group('CancellationManager', () {
    late Directory workDir;
    late String palettePath;
    late String outPath;

    setUp(() async {
      workDir = await Directory.systemTemp.createTemp('gifforge_cancel_');
      palettePath = '${workDir.path}/palette.png';
      outPath = '${workDir.path}/out.gif';
      await File(palettePath).writeAsString('palette');
      await File(outPath).writeAsString('partial');
    });

    tearDown(() async {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    });

    CancellationManager build(CancelToken token) => CancellationManager(
      token: token,
      tempFiles: [palettePath, outPath],
      workDir: workDir.path,
    );

    test('cancel:标记 token + 清理全部临时文件', () async {
      final token = CancelToken();
      await build(token).cancel();

      expect(token.isCancelled, isTrue);
      expect(File(palettePath).existsSync(), isFalse);
      expect(File(outPath).existsSync(), isFalse);
      expect(workDir.existsSync(), isFalse, reason: '目录清空后移除');
    });

    test('重复取消无副作用(幂等)', () async {
      final token = CancelToken();
      final manager = build(token);

      await manager.cancel();
      await manager.cancel(); // 不应抛、不再动文件

      expect(token.isCancelled, isTrue);
      expect(manager.isCancelled, isTrue);
    });

    test('cleanupTempFiles:文件不存在时跳过,目录保留非临时文件', () async {
      final manager = build(CancelToken());
      await File(outPath).delete(); // 不存在的文件跳过删除
      final other = File('${workDir.path}/other.txt');
      await other.writeAsString('keep'); // 非 tempFiles 内容

      await manager.cleanupTempFiles();

      expect(File(palettePath).existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(workDir.existsSync(), isTrue, reason: '含非临时文件不删除目录');
    });

    test('cancel 前调用 cleanupTempFiles 再 cancel 仍幂等', () async {
      final token = CancelToken();
      final manager = build(token);

      await manager.cleanupTempFiles();
      await manager.cancel();

      expect(manager.isCancelled, isTrue);
      expect(workDir.existsSync(), isFalse);
    });
  });
}

class FakeProcessHandle implements ProcessHandle {
  bool exited = false;

  /// true:普通 kill 即退出;false:仅强杀退出。
  bool exitsOnKill = true;

  final List<bool> kills = [];

  @override
  bool get hasExited => exited;

  @override
  Future<void> kill({bool force = false}) async {
    kills.add(force);
    if (force || exitsOnKill) {
      exited = true;
    }
  }
}
