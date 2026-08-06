import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/shared/providers/core_providers.dart';

/// 素材存储状态(设置页「素材存储」分组)。
class CapturesStorageState {
  const CapturesStorageState({
    this.totalBytes = 0,
    this.fileCount = 0,
    this.loading = false,
  });

  /// 素材目录占用总字节。
  final int totalBytes;

  /// 素材文件数。
  final int fileCount;
  final bool loading;

  CapturesStorageState copyWith({
    int? totalBytes,
    int? fileCount,
    bool? loading,
  }) {
    return CapturesStorageState(
      totalBytes: totalBytes ?? this.totalBytes,
      fileCount: fileCount ?? this.fileCount,
      loading: loading ?? this.loading,
    );
  }
}

/// 素材存储控制器(设置页分组;autoDispose)。
///
/// load 统计素材目录占用(异步,避免阻塞 UI);clear 清空素材文件
/// (保留目录;历史重转对已删素材已有预检提示,删除安全)。
class CapturesStorageController extends Notifier<CapturesStorageState> {
  @override
  CapturesStorageState build() => const CapturesStorageState();

  /// 统计素材目录占用(异步)。
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);
    try {
      final dir = ref.read(capturesFileDirProvider);
      var bytes = 0;
      var count = 0;
      if (dir.existsSync()) {
        for (final f in dir.listSync(recursive: true)) {
          if (f is File) {
            bytes += f.lengthSync();
            count++;
          }
        }
      }
      state = CapturesStorageState(totalBytes: bytes, fileCount: count);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 清空素材文件(保留目录;幂等)。
  Future<void> clear() async {
    final dir = ref.read(capturesFileDirProvider);
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        try {
          if (f is File) {
            f.deleteSync();
          } else if (f is Directory) {
            f.deleteSync(recursive: true);
          }
        } on FileSystemException {
          // 忽略:单文件清理失败不阻塞
        }
      }
    }
    await load();
  }
}

final capturesStorageControllerProvider =
    NotifierProvider.autoDispose<
      CapturesStorageController,
      CapturesStorageState
    >(CapturesStorageController.new);
