import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/per_image_control.dart';
import '../../features/import/application/import_providers.dart';

/// 单图精细化控制会话状态(模态页,autoDispose 随 pop 销毁)。
class ImageControlFormState {
  const ImageControlFormState({
    this.multiplier = 1.0,
    this.width = 0,
    this.height = 0,
    this.sourceSize,
    this.probeFailed = false,
    this.canvasW = 0,
    this.canvasH = 0,
  });

  /// 等比缩放倍数(默认 1;仅宽高均 0 时生效)。
  final double multiplier;

  /// 控制宽度(0 = 该图自身比例)。
  final int width;

  /// 控制高度(0 = 该图自身比例)。
  final int height;

  /// 该图源尺寸(探测成功后填充;预览模拟与保存校验依据)。
  final ({int width, int height})? sourceSize;

  /// 源尺寸探测失败(页面禁用编辑)。
  final bool probeFailed;

  /// 统一画布尺寸(0 = 未知,预览退化为图片自身比例)。
  final int canvasW;
  final int canvasH;

  bool get hasCanvas => canvasW > 0 && canvasH > 0;

  /// 当前控制值对象(保存 pop 返回值)。
  PerImageControl get control => PerImageControl(
    scaleMultiplier: multiplier,
    width: width,
    height: height,
  );

  ImageControlFormState copyWith({
    double? multiplier,
    int? width,
    int? height,
    ({int width, int height})? sourceSize,
    bool? probeFailed,
    int? canvasW,
    int? canvasH,
  }) {
    return ImageControlFormState(
      multiplier: multiplier ?? this.multiplier,
      width: width ?? this.width,
      height: height ?? this.height,
      sourceSize: sourceSize ?? this.sourceSize,
      probeFailed: probeFailed ?? this.probeFailed,
      canvasW: canvasW ?? this.canvasW,
      canvasH: canvasH ?? this.canvasH,
    );
  }
}

/// 单图精细化控制会话控制器(app 层组合,autoDispose)。
///
/// 承载:播种初始控制 + 源尺寸探测、自定义宽高/倍数的解析与范围校验
/// (返回错误文案,UI 弹 SnackBar)、预设赋值、恢复默认、保存校验;
/// 结果经 `PerImageControl` pop 返回值回传 image_gif 会话(契约不变)。
class ImageControlController extends Notifier<ImageControlFormState> {
  @override
  ImageControlFormState build() => const ImageControlFormState();

  /// 会话初始化:播种初始控制 + 探测源尺寸(失败 → probeFailed)。
  Future<void> init({
    required String path,
    required int canvasW,
    required int canvasH,
    required PerImageControl? initial,
  }) async {
    state = ImageControlFormState(
      multiplier: initial?.scaleMultiplier ?? 1.0,
      width: initial?.width ?? 0,
      height: initial?.height ?? 0,
      canvasW: canvasW,
      canvasH: canvasH,
    );
    if (path.isEmpty) return;
    try {
      final size = await ref.read(imageProbePortProvider).probe(path);
      if (!ref.mounted) return;
      state = state.copyWith(sourceSize: size);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(probeFailed: true);
    }
  }

  /// 自定义缩放倍数文本(0.1–4):非法返回错误文案,成功应用返回 null。
  String? tryUpdateCustomScaleMultiplier(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0 || v > 4) return '缩放倍数须为 0.1–4 的数字';
    state = state.copyWith(multiplier: v);
    return null;
  }

  /// 自定义宽度文本(1–4096):非法返回错误文案,成功应用返回 null。
  String? tryUpdateCustomWidth(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) return '宽度须为 1–4096 的数字';
    state = state.copyWith(width: v);
    return null;
  }

  /// 自定义高度文本(1–4096):非法返回错误文案,成功应用返回 null。
  String? tryUpdateCustomHeight(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) return '高度须为 1–4096 的数字';
    state = state.copyWith(height: v);
    return null;
  }

  /// 预设赋值(下拉选项表,值恒合法,无需校验)。
  void updateMultiplier(double v) => state = state.copyWith(multiplier: v);

  void updateWidth(int v) => state = state.copyWith(width: v);

  void updateHeight(int v) => state = state.copyWith(height: v);

  /// 恢复默认 (1, 0, 0)。
  void reset() => state = state.copyWith(multiplier: 1.0, width: 0, height: 0);

  /// 保存校验:有控制(非默认)时必须能算出目标(源尺寸未知 → 拒绝,
  /// 预览无意义且命令构造无画布兜底);失败返回文案,成功返回 null。
  String? validateSave() {
    final s = state;
    if (!s.control.isDefault && s.sourceSize == null && s.hasCanvas) {
      return '无法读取图片尺寸,请更换图片';
    }
    return null;
  }
}

/// 单图精细化控制会话 provider(模态页,autoDispose 随 pop 销毁)。
final imageControlControllerProvider =
    NotifierProvider.autoDispose<ImageControlController, ImageControlFormState>(
      ImageControlController.new,
    );
