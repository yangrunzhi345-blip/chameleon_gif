import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/repository_interfaces/file_pick_port.dart';
import '../../../domain/repository_interfaces/image_probe_port.dart';
import '../../../shared/providers/core_providers.dart';
import '../infrastructure/file_picker_port_impl.dart';
import '../infrastructure/image_probe_port_impl.dart';
import 'import_video_use_case.dart';

/// 文件选择端口(测试经 override 注入 Fake)。
final filePickPortProvider = Provider<FilePickPort>(
  (ref) => const FilePickerPortImpl(),
);

/// 图片尺寸探测端口(图片→GIF 命令构造输入;测试经 override 注入 Fake)。
final imageProbePortProvider = Provider<ImageProbePort>(
  (ref) => const ImageProbePortImpl(),
);

/// 导入视频解析用例(P1 能力接线)。
final importVideoUseCaseProvider = Provider<ImportVideoUseCase>(
  (ref) => ImportVideoUseCase(
    parseVideoPort: ref.watch(parseVideoPortProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);
