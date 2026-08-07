import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/entities/export_history.dart';
import '../../domain/entities/export_task.dart';
import '../../domain/repository_interfaces/history_repository.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../../domain/value_objects/task_state.dart';
import '../../shared/providers/core_providers.dart';

/// 缓存分区(设置页「存储管理」统计口径)。
enum CachePartition {
  /// file_picker 导入副本(`<temp>/file_picker/`,选择即复制,最大泄漏点)
  filePickerCopies,

  /// 转换工作目录(`<temp>/gifforge_*`,含残留中间片/输出)
  workDirs,

  /// 历史缩略图(`<temp>/gifforge_thumbs`)
  thumbs,
}

/// 缓存存储状态(设置页「存储管理」分组)。
class CacheStorageState {
  const CacheStorageState({this.partitions = const {}, this.loading = false});

  /// 各分区统计(分区 → (文件数, 字节))。
  final Map<CachePartition, ({int count, int bytes})> partitions;
  final bool loading;

  int get totalBytes => partitions.values.fold(0, (acc, v) => acc + v.bytes);

  int get totalCount => partitions.values.fold(0, (acc, v) => acc + v.count);

  CacheStorageState copyWith({
    Map<CachePartition, ({int count, int bytes})>? partitions,
    bool? loading,
  }) {
    return CacheStorageState(
      partitions: partitions ?? this.partitions,
      loading: loading ?? this.loading,
    );
  }
}

/// 缓存清理策略常量(2026-08-07 缓存 1.3GB 膨胀修复)。
abstract final class CachePolicy {
  /// file_picker 副本保留期:超过该时长且未被任何任务/历史引用 → 删。
  static const filePickerTtl = Duration(days: 7);

  /// 工作目录保留期:任务不存在或终态且超过该时长 → 删。
  static const workDirTtl = Duration(days: 7);

  /// 缩略图磁盘上限(与 ThumbnailExtractor LRU 一致,兜底强制)。
  static const maxThumbFiles = 256;
}

/// 缓存存储控制器(设置页分组 + 启动自动清理;autoDispose)。
///
/// 统计/清理口径:
/// - `runStartupCleanup`:启动时异步执行一次 —— file_picker 副本
///   **未被 Isar 引用**(videoPath/outputPath/imagePaths 全集)且超
///   [CachePolicy.filePickerTtl] 删;workdir 任务不存在或终态且超
///   [CachePolicy.workDirTtl] 删;缩略图超额按 mtime LRU 兜底。
///   运行中/排队任务目录不删(与 TaskManager 恢复解耦)。
/// - `clear`:设置页手动清空 —— 副本全清 + workdir(非 running)全清 +
///   缩略图全清;文案明示"部分历史重转需重新选择源文件"。
///
/// 依赖构造注入(单测经 ProviderContainer.overrideWith 注 fake 仓储 +
/// 临时目录 + 时钟);未注入时从 ref 读组合根装配的实现。
class CacheStorageController extends Notifier<CacheStorageState> {
  CacheStorageController({
    TaskRepository? taskRepository,
    HistoryRepository? historyRepository,
    AppLogger? logger,
    DateTime Function()? now,
    String? systemTempDir,
  }) : _taskRepository = taskRepository,
       _historyRepository = historyRepository,
       _logger = logger,
       _now = now ?? DateTime.now,
       _tempDir = systemTempDir ?? Directory.systemTemp.path;

  final TaskRepository? _taskRepository;
  final HistoryRepository? _historyRepository;
  final AppLogger? _logger;
  final DateTime Function() _now;
  final String _tempDir;

  TaskRepository get _tasks =>
      _taskRepository ?? ref.read(taskRepositoryProvider);

  HistoryRepository get _histories =>
      _historyRepository ?? ref.read(historyRepositoryProvider);

  AppLogger get _log => _logger ?? ref.read(appLoggerProvider);

  @override
  CacheStorageState build() => const CacheStorageState();

  // ---- 统计 ----

  /// 统计各分区占用(异步;数据量小,同步遍历无碍)。
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);
    try {
      state = CacheStorageState(partitions: await _statPartitions());
    } finally {
      if (ref.mounted) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<Map<CachePartition, ({int count, int bytes})>> _statPartitions() {
    return Future.sync(() {
      return {
        CachePartition.filePickerCopies: _statDir(
          Directory('$_tempDir/file_picker'),
          recursive: true,
        ),
        CachePartition.workDirs: _statGlob(_tempDir, 'gifforge_*'),
        CachePartition.thumbs: _statDir(
          Directory('$_tempDir/gifforge_thumbs'),
          recursive: false,
        ),
      };
    });
  }

  ({int count, int bytes}) _statDir(Directory dir, {required bool recursive}) {
    if (!dir.existsSync()) return (count: 0, bytes: 0);
    var count = 0;
    var bytes = 0;
    for (final f in dir.listSync(recursive: recursive)) {
      if (f is File) {
        bytes += f.lengthSync();
        count++;
      }
    }
    return (count: count, bytes: bytes);
  }

  ({int count, int bytes}) _statGlob(String root, String pattern) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) return (count: 0, bytes: 0);
    var count = 0;
    var bytes = 0;
    for (final f in rootDir.listSync()) {
      if (f is Directory && _matchesGlob(f.path, pattern)) {
        final s = _statDir(f, recursive: true);
        count += s.count;
        bytes += s.bytes;
      }
    }
    return (count: count, bytes: bytes);
  }

  bool _matchesGlob(String path, String pattern) {
    final name = path.split(Platform.pathSeparator).last;
    if (pattern == 'gifforge_*') {
      // 排除缩略图目录(gifforge_thumbs 以同前缀开头,独立分区统计/清理)
      return name.startsWith('gifforge_') &&
          !name.startsWith('gifforge_thumbs');
    }
    return false;
  }

  // ---- 引用豁免集 ----

  /// 全量 Isar 引用路径集(任务 + 历史;videoPath/outputPath/imagePaths)。
  ///
  /// 清理豁免依据:副本/输出仍被近期记录引用时不删,保住历史重转能力
  /// (1.3GB 积累的主要构成是"选过但从未入队"或"已超期"的副本)。
  Future<Set<String>> _referencedPaths() async {
    final paths = <String>{};
    final tasks = await _tasks.all();
    final histories = await _histories.list();
    void collect(ExportTask task) {
      if (task.videoPath.isNotEmpty) paths.add(task.videoPath);
      final out = task.outputPath;
      if (out != null && out.isNotEmpty) paths.add(out);
      final imgs = task.imagePaths;
      if (imgs != null) paths.addAll(imgs);
    }

    void collectHistory(ExportHistory h) {
      if (h.videoPath.isNotEmpty) paths.add(h.videoPath);
      if (h.outputPath.isNotEmpty) paths.add(h.outputPath);
      final imgs = h.imagePaths;
      if (imgs != null) paths.addAll(imgs);
    }

    for (final t in tasks) {
      collect(t);
    }
    for (final h in histories) {
      collectHistory(h);
    }
    return paths;
  }

  // ---- 自动清理(启动一次) ----

  /// 启动自动清理:异常仅记日志,绝不阻塞首帧。
  Future<void> runStartupCleanup() async {
    try {
      final referenced = await _referencedPaths();
      final cutoff = _now().subtract(CachePolicy.filePickerTtl);
      // 1) file_picker 副本:未被引用且超期 → 删;空时间戳子目录回收
      final pickerDir = Directory('$_tempDir/file_picker');
      if (pickerDir.existsSync()) {
        for (final entry in pickerDir.listSync()) {
          try {
            if (entry is File) {
              _deleteIf(entry, referenced: referenced, cutoff: cutoff);
            } else if (entry is Directory) {
              var changed = false;
              for (final f in entry.listSync()) {
                if (f is File) {
                  changed =
                      _deleteIf(f, referenced: referenced, cutoff: cutoff) ||
                      changed;
                }
              }
              // 空目录回收(该批次副本已全部清理)
              if (changed && entry.listSync().isEmpty) {
                entry.deleteSync();
              }
            }
          } on FileSystemException catch (e) {
            _log.w('启动清理 file_picker 失败: ${entry.path}', error: e);
          }
        }
      }
      // 2) 工作目录:任务不存在或终态且超期 → 删
      final runningIds = <int>{
        for (final t in await _tasks.all())
          if (t.state == TaskState.queued || t.state == TaskState.running) t.id,
      };
      await _cleanupWorkDirs(runningIds: runningIds, cutoff: cutoff);
      // 3) 缩略图超额兜底(与 ThumbnailExtractor 同 LRU 语义)
      _cleanupThumbsOverflow();
      _log.i('启动缓存清理完成');
    } on Object catch (e, st) {
      _log.w('启动缓存清理失败', error: e, stackTrace: st);
    }
  }

  /// 单文件删除判断:未被引用且 mtime 早于 [cutoff]。
  bool _deleteIf(
    File file, {
    required Set<String> referenced,
    required DateTime cutoff,
  }) {
    if (referenced.contains(file.path)) return false;
    try {
      if (file.statSync().modified.isBefore(cutoff)) {
        file.deleteSync();
        return true;
      }
    } on FileSystemException catch (e) {
      _log.w('删除缓存文件失败: ${file.path}', error: e);
    }
    return false;
  }

  Future<void> _cleanupWorkDirs({
    required Set<int> runningIds,
    required DateTime cutoff,
  }) async {
    final root = Directory(_tempDir);
    if (!root.existsSync()) return;
    for (final f in root.listSync()) {
      if (f is! Directory || !_matchesGlob(f.path, 'gifforge_*')) {
        continue;
      }
      // 目录名 gifforge_<taskId>
      final id = int.tryParse(f.path.split('/').last.substring(9));
      try {
        if ((id == null || !runningIds.contains(id)) &&
            f.statSync().modified.isBefore(cutoff)) {
          f.deleteSync(recursive: true);
        }
      } on FileSystemException catch (e) {
        _log.w('清理工作目录失败: ${f.path}', error: e);
      }
    }
  }

  /// 缩略图磁盘超额兜底(> [CachePolicy.maxThumbFiles] 按 mtime 删最旧)。
  void _cleanupThumbsOverflow() {
    final dir = Directory('$_tempDir/gifforge_thumbs');
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    if (files.length <= CachePolicy.maxThumbFiles) return;
    for (final f in files.take(files.length - CachePolicy.maxThumbFiles)) {
      try {
        f.deleteSync();
      } on FileSystemException catch (e) {
        _log.w('清理缩略图失败: ${f.path}', error: e);
      }
    }
  }

  // ---- 手动清空(设置页) ----

  /// 手动清空缓存:副本全清 + workdir(非 running)全清 + 缩略图全清。
  ///
  /// 副本全清会破坏"指向副本的历史重转"(用户二次确认文案明示);
  /// 运行中任务的 workdir 保留(避免破坏进行中转换)。
  Future<void> clear() async {
    // 副本全清(不豁免引用)
    final pickerDir = Directory('$_tempDir/file_picker');
    if (pickerDir.existsSync()) {
      for (final entry in pickerDir.listSync()) {
        try {
          if (entry is Directory) {
            entry.deleteSync(recursive: true);
          } else {
            entry.deleteSync();
          }
        } on FileSystemException catch (e) {
          _log.w('清空 file_picker 失败: ${entry.path}', error: e);
        }
      }
    }
    // workdir:仅清理非 running/queued(进行中任务的目录保留)
    final activeIds = <int>{
      for (final t in await _tasks.all())
        if (t.state == TaskState.queued || t.state == TaskState.running) t.id,
    };
    await _cleanupWorkDirs(runningIds: activeIds, cutoff: _now());
    // 缩略图全清
    final thumbsDir = Directory('$_tempDir/gifforge_thumbs');
    if (thumbsDir.existsSync()) {
      try {
        thumbsDir.deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        _log.w('清空缩略图失败', error: e);
      }
    }
    await load();
  }
}

final cacheStorageControllerProvider =
    NotifierProvider.autoDispose<CacheStorageController, CacheStorageState>(
      CacheStorageController.new,
    );
