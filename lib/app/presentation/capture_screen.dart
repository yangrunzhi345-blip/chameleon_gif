import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 相机拍摄页(路由 /capture;docs/18 C1-WP3)。
///
/// 占位壳:完整实现(取景/录制/倒计时/自动导入)随拍摄闭环提交落地,
/// 本壳保证共享面(路由/首页入口)可独立编译与测试。
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('相机拍摄')),
      body: const Center(child: Text('相机拍摄开发中…')),
    );
  }
}
