import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

/// 录屏设置分组状态(能力固定无探测,比相机组轻)。
class RecordSettingsState {
  const RecordSettingsState({this.params = const RecordParams()});

  final RecordParams params;

  RecordSettingsState copyWith({RecordParams? params}) =>
      RecordSettingsState(params: params ?? this.params);
}

/// 录屏设置控制器(autoDispose,会话级)。
///
/// init 载入持久化参数;变更即更新状态(无端口调用,录屏无 live apply);
/// save 持久化(record_params)。
class RecordSettingsController extends Notifier<RecordSettingsState> {
  @override
  RecordSettingsState build() {
    final repo = ref.read(settingsRepositoryProvider);
    return RecordSettingsState(
      params: repo.recordParams ?? const RecordParams(),
    );
  }

  Future<void> updateParams(RecordParams params) async {
    state = state.copyWith(params: params);
  }

  /// 持久化当前参数(设置页「保存设置」统一调用)。
  Future<void> save() async {
    await ref.read(settingsRepositoryProvider).setRecordParams(state.params);
  }
}

final recordSettingsControllerProvider =
    NotifierProvider.autoDispose<RecordSettingsController, RecordSettingsState>(
      RecordSettingsController.new,
    );
