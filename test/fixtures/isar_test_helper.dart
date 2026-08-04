import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
// Abi/IsarAbi 未从包入口导出,直接 import 内部定义(仅测试用)
import 'package:isar_community/src/native/isar_core.dart' show IsarAbi;

bool _nativeReady = false;

/// 初始化 Isar 原生库(单元测试环境,非 Flutter 运行时)。
///
/// 从 `.dart_tool/package_config.json` 解析 `isar_community_flutter_libs`
/// 包路径并加载其内置 libisar 动态库(避免 download 污染项目根)。
/// 幂等;桌面三平台按 ABI 取对应库文件。
Future<void> initIsarNative() async {
  if (_nativeReady) return;
  _nativeReady = true;

  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw StateError('未找到 .dart_tool/package_config.json,请先 flutter pub get');
  }
  final packages =
      ((jsonDecode(configFile.readAsStringSync()) as Map)['packages'] as List)
          .cast<Map>()
          .cast<Map<dynamic, dynamic>>();
  final libs = packages.firstWhere(
    (p) => p['name'] == 'isar_community_flutter_libs',
  );
  final root = Uri.parse(libs['rootUri'] as String).toFilePath();

  final String libName;
  if (Platform.isLinux) {
    libName = 'linux/libisar.so';
  } else if (Platform.isMacOS) {
    libName = 'macos/Frameworks/libisar.dylib';
  } else if (Platform.isWindows) {
    libName = r'windows\libisar.dll';
  } else {
    throw StateError('不支持的测试平台: ${Platform.operatingSystem}');
  }
  final libraryPath = '$root/$libName';
  if (!File(libraryPath).existsSync()) {
    throw StateError('isar 原生库缺失: $libraryPath');
  }

  await Isar.initializeIsarCore(libraries: {IsarAbi.current(): libraryPath});
}
