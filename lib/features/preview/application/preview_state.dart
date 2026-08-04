import '../../../domain/entities/video_info.dart';

/// 预览会话生命周期态。
enum PreviewLifecycle { idle, loading, ready, error }

/// 预览会话状态(不可变;普通类不引 freezed——状态极简且无 JSON 需求)。
///
/// 高频连续量(position/duration)不进入本状态,按 docs/09-状态管理.md §9.3
/// 与 docs/06 M02 契约走独立流(positionStream/durationStream),避免 Notifier
/// 每帧重建 watcher。
class PreviewState {
  const PreviewState._({
    required this.lifecycle,
    this.video,
    this.errorCode,
    this.errorMessage,
    this.isPlaying = false,
    this.isCompleted = false,
  });

  const PreviewState.idle() : this._(lifecycle: PreviewLifecycle.idle);

  const PreviewState.loading(VideoInfo video)
    : this._(lifecycle: PreviewLifecycle.loading, video: video);

  const PreviewState.ready(
    VideoInfo video, {
    bool isPlaying = true,
    bool isCompleted = false,
  }) : this._(
         lifecycle: PreviewLifecycle.ready,
         video: video,
         isPlaying: isPlaying,
         isCompleted: isCompleted,
       );

  const PreviewState.error({
    required String errorCode,
    String? errorMessage,
    VideoInfo? video,
  }) : this._(
         lifecycle: PreviewLifecycle.error,
         video: video,
         errorCode: errorCode,
         errorMessage: errorMessage,
       );

  final PreviewLifecycle lifecycle;
  final VideoInfo? video;
  final String? errorCode;
  final String? errorMessage;
  final bool isPlaying;
  final bool isCompleted;

  PreviewState copyWith({bool? isPlaying, bool? isCompleted}) => PreviewState._(
    lifecycle: lifecycle,
    video: video,
    errorCode: errorCode,
    errorMessage: errorMessage,
    isPlaying: isPlaying ?? this.isPlaying,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
