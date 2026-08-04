import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/application/providers.dart';
import '../../../domain/repository_interfaces/file_pick_port.dart';
import '../infrastructure/file_picker_port_impl.dart';
import 'import_video_use_case.dart';

/// 文件选择端口(测试经 override 注入 Fake)。
final filePickPortProvider = Provider<FilePickPort>(
  (ref) => const FilePickerPortImpl(),
);

/// 导入视频解析用例(P1 能力接线)。
final importVideoUseCaseProvider = Provider<ImportVideoUseCase>(
  (ref) => ImportVideoUseCase(
    parseVideoPort: ref.watch(parseVideoPortProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);
