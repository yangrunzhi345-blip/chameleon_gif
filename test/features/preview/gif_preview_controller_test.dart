import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/features/preview/application/gif_preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_state.dart';

/// [GifPreviewController] 测试(普通 test:真实异步,无 FakeAsync)。
///
/// 说明:测试环境(flutter_tester)无 rasterizer,`ui.decodeImageFromPixels`
/// 回调不触发,无法构造真实 [ui.Image] —— 故 ready 链路(帧推进/缓存/
/// seek 定位)注入假解码 **抛异常** 的控制器,验证失败路径与防御行为;
/// 帧推进/缓存等成功路径逻辑由真机验证(见 docs/14-测试计划.md 真机清单)。
void main() {
  late Directory dir;
  late File gifFile;
  late ProviderContainer container;

  VideoInfo gifInfo(String path) => VideoInfo(
    path: path,
    formatName: 'gif',
    duration: Duration.zero,
    width: 0,
    height: 0,
    fps: null,
    codec: 'gif',
  );

  setUp(() async {
    // 2 帧 GIF fixture(帧延迟 50ms,GifEncoder.delay 单位 1/100 秒)
    final f0 = img.Image(width: 2, height: 2)
      ..setPixelRgba(0, 0, 255, 0, 0, 255);
    final f1 = img.Image(width: 2, height: 2)
      ..setPixelRgba(0, 0, 0, 0, 255, 255);
    final encoder = img.GifEncoder(delay: 5)
      ..addFrame(f0)
      ..addFrame(f1);
    dir = await Directory.systemTemp.createTemp('gif_ctrl_');
    gifFile = File('${dir.path}/demo.gif')..writeAsBytesSync(encoder.finish()!);
  });

  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer() {
    container = ProviderContainer(
      overrides: [
        gifPreviewControllerProvider.overrideWith(
          () => GifPreviewController(
            decodeFrame: (bytes, index) async {
              throw const FormatException('测试注入解码失败');
            },
          ),
        ),
      ],
    );
    // autoDispose 保活:无监听者时 async 方法挂起期间 provider 会被回收,
    // 后续 state 写入静默丢弃(load 永远停在 loading/无效)
    container.listen(gifPreviewControllerProvider, (_, _) {});
    return container;
  }

  test('load 失败(文件不存在)→ error 态', () async {
    buildContainer();
    final ctl = container.read(gifPreviewControllerProvider.notifier);

    await ctl.load(gifInfo('${dir.path}/missing.gif'));

    final state = container.read(gifPreviewControllerProvider);
    expect(state.lifecycle, PreviewLifecycle.error);
    expect(state.errorMessage, contains('加载失败'));
  });

  test('解码异常 → error 态(不悬挂)', () async {
    buildContainer();
    final ctl = container.read(gifPreviewControllerProvider.notifier);

    await ctl.load(gifInfo(gifFile.path));

    final state = container.read(gifPreviewControllerProvider);
    expect(state.lifecycle, PreviewLifecycle.error);
    expect(state.video?.path, gifFile.path, reason: '错误态保留上下文');
  });

  test('play/pause/seek 在非 ready 态防御性跳过', () async {
    buildContainer();
    final ctl = container.read(gifPreviewControllerProvider.notifier);

    ctl.play(); // idle
    ctl.pause();
    await ctl.seekTo(const Duration(milliseconds: 10));
    expect(
      container.read(gifPreviewControllerProvider).lifecycle,
      PreviewLifecycle.idle,
      reason: '防御:无任务时不改状态',
    );
  });

  test('重复 load 重置状态流(切文件场景)', () async {
    buildContainer();
    final ctl = container.read(gifPreviewControllerProvider.notifier);

    await ctl.load(gifInfo(gifFile.path)); // 解码失败 → error
    await ctl.load(gifInfo('${dir.path}/missing2.gif')); // 重新加载

    final state = container.read(gifPreviewControllerProvider);
    expect(state.video?.path, '${dir.path}/missing2.gif');
    expect(state.lifecycle, PreviewLifecycle.error);
  });
}
