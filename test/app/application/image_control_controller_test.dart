import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/image_control_controller.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/per_image_control.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_image_probe_port.dart';

/// [ImageControlController] 单测:播种/探测/try* 校验/重置/保存守卫。
void main() {
  late ProviderContainer container;

  ProviderContainer build({FakeImageProbePort? probe}) {
    return ProviderContainer(
      overrides: [
        appLoggerProvider.overrideWithValue(AppLogger()),
        // 用例 provider 依赖 parseVideoPort(导入用例 watch 链),补注入
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        imageProbePortProvider.overrideWithValue(
          probe ?? FakeImageProbePort(width: 64, height: 64),
        ),
      ],
    )..listen(imageControlControllerProvider, (_, _) {});
  }

  ImageControlFormState state() =>
      container.read(imageControlControllerProvider);

  setUp(() => container = build());

  tearDown(() => container.dispose());

  test('init:播种初始控制 + 探测成功填充源尺寸', () async {
    final notifier = container.read(imageControlControllerProvider.notifier);
    await notifier.init(
      path: '/img/a.png',
      canvasW: 480,
      canvasH: 270,
      initial: const PerImageControl(scaleMultiplier: 2),
    );

    expect(state().multiplier, 2);
    expect(state().width, 0);
    expect(state().height, 0);
    expect(state().sourceSize, (width: 64, height: 64));
    expect(state().probeFailed, isFalse);
  });

  test('init:无初始控制 → 默认 (1, 0, 0);空 path 不探测', () async {
    final notifier = container.read(imageControlControllerProvider.notifier);
    await notifier.init(path: '', canvasW: 0, canvasH: 0, initial: null);

    expect(state().multiplier, 1.0);
    expect(state().sourceSize, isNull);
  });

  test('init:探测失败 → probeFailed(页面禁用编辑)', () async {
    container = build(
      probe: FakeImageProbePort(error: StateError('decode failed')),
    );
    final notifier = container.read(imageControlControllerProvider.notifier);

    await notifier.init(
      path: '/img/broken.png',
      canvasW: 0,
      canvasH: 0,
      initial: null,
    );

    expect(state().probeFailed, isTrue);
  });

  test('tryUpdateCustomScaleMultiplier:非法 → 文案,合法 → 应用返回 null', () {
    final notifier = container.read(imageControlControllerProvider.notifier);

    expect(notifier.tryUpdateCustomScaleMultiplier('0'), '缩放倍数须为 0.1–4 的数字');
    expect(notifier.tryUpdateCustomScaleMultiplier('4.1'), isNotNull);
    expect(notifier.tryUpdateCustomScaleMultiplier('abc'), isNotNull);
    expect(state().multiplier, 1.0, reason: '非法不修改');

    expect(notifier.tryUpdateCustomScaleMultiplier('1.5'), isNull);
    expect(state().multiplier, 1.5);
  });

  test('tryUpdateCustomWidth/Height:边界 1/4096 合法,越界非法', () {
    final notifier = container.read(imageControlControllerProvider.notifier);

    expect(notifier.tryUpdateCustomWidth('0'), '宽度须为 1–4096 的数字');
    expect(notifier.tryUpdateCustomWidth('4097'), isNotNull);
    expect(notifier.tryUpdateCustomWidth('1'), isNull);
    expect(state().width, 1);
    expect(notifier.tryUpdateCustomWidth('4096'), isNull);
    expect(state().width, 4096);

    expect(notifier.tryUpdateCustomHeight('0'), '高度须为 1–4096 的数字');
    expect(notifier.tryUpdateCustomHeight('100'), isNull);
    expect(state().height, 100);
  });

  test('预设赋值与恢复默认', () {
    final notifier = container.read(imageControlControllerProvider.notifier);

    notifier.updateMultiplier(2);
    notifier.updateWidth(320);
    notifier.updateHeight(180);
    expect(state().multiplier, 2);
    expect(state().width, 320);
    expect(state().height, 180);

    notifier.reset();
    expect(state().multiplier, 1.0);
    expect(state().width, 0);
    expect(state().height, 0);
  });

  test('validateSave:有控制且源尺寸未知且画布已知 → 拒绝文案', () async {
    container = build(probe: FakeImageProbePort(error: StateError('decode')));
    final notifier = container.read(imageControlControllerProvider.notifier);
    await notifier.init(
      path: '/img/broken.png',
      canvasW: 480,
      canvasH: 270,
      initial: null,
    );

    notifier.updateWidth(320);
    expect(notifier.validateSave(), '无法读取图片尺寸,请更换图片');

    // 恢复默认(无控制)→ 放行
    notifier.reset();
    expect(notifier.validateSave(), isNull);
  });

  test('validateSave:源尺寸已知或有画布未知 → 放行', () async {
    final notifier = container.read(imageControlControllerProvider.notifier);
    await notifier.init(
      path: '/img/a.png',
      canvasW: 480,
      canvasH: 270,
      initial: null,
    );

    notifier.updateMultiplier(2);
    expect(notifier.validateSave(), isNull);

    // 画布未知(0,0):命令构造无画布兜底,源尺寸未知也不拒绝
    final notifier2 = container.read(imageControlControllerProvider.notifier);
    await notifier2.init(path: '', canvasW: 0, canvasH: 0, initial: null);
    notifier2.updateWidth(320);
    expect(notifier2.validateSave(), isNull);
  });
}

/// 解析端口替身(用例 provider watch 链需要,本测试不触发解析)。
class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 1),
    width: 64,
    height: 64,
    fps: 15,
    codec: 'h264',
  );
}
