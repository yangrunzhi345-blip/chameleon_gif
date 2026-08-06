import 'package:flutter/material.dart';

/// 数字输入对话框(自定义宽高/倍数的输入入口,三个面板共用)。
///
/// 返回输入的文本;取消或确定但文本为空时返回 null。
/// 数值校验(范围/格式)由调用方面板完成,非法 → formError 提示。
Future<String?> showCustomValueDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String hintText,
}) {
  final controller = TextEditingController(text: initialValue);
  // 一次性守卫:连点确定/取消会第二次 pop,弹掉调用方页面路由
  var tapped = false;
  void guard(VoidCallback action) {
    if (tapped) return;
    tapped = true;
    action();
  }

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: hintText,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        onSubmitted: (v) {
          final text = v.trim();
          if (text.isNotEmpty) guard(() => Navigator.of(context).pop(text));
        },
      ),
      actions: [
        TextButton(
          onPressed: () => guard(() => Navigator.of(context).pop()),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => guard(() {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          }),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
