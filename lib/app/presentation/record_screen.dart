import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 屏幕录制页(路由 /record;docs/19 S1-WP3)。
///
/// 占位壳:完整实现(授权/录制/倒计时/自动导入)随录屏闭环提交落地,
/// 本壳保证共享面(路由/首页入口)可独立编译与测试。
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕录制')),
      body: const Center(child: Text('屏幕录制开发中…')),
    );
  }
}
