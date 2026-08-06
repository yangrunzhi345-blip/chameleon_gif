/// ffmpeg image2pipe JPEG 帧分割器(纯 Dart,可单测)。
///
/// 输入:ffmpeg `-f image2pipe -vcodec mjpeg pipe:1` 的连续字节流
/// (每帧为独立 JPEG,SOI `0xFFD8` 起始 / EOI `0xFFD9` 结束,帧间直接
/// 拼接)。输出:完整 JPEG 帧列表;不完整尾帧暂存等待补齐。
///
/// JPEG 熵编码数据中的 `0xFF` 后必跟 `0x00`(byte stuffing),故
/// `0xFFD8`/`0xFFD9` 只出现在帧边界,分割可靠。
library;

import 'dart:typed_data';

/// JPEG 帧分割器(流式;addChunk 可能输出 0..n 帧)。
class JpegFrameSplitter {
  final _buffer = BytesBuilder();

  /// 追加字节块,切出所有完整 JPEG 帧(按出现顺序)。
  List<Uint8List> addChunk(Uint8List chunk) {
    _buffer.add(chunk);
    final bytes = _buffer.toBytes();
    final frames = <Uint8List>[];
    var start = -1;
    var i = 0;
    while (i < bytes.length - 1) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
        start = i;
        i += 2;
        continue;
      }
      if (start >= 0 && bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        // EOI 标记含两个字节,帧 = [SOI..EOI+1]
        frames.add(Uint8List.fromList(bytes.sublist(start, i + 2)));
        start = -1;
        i += 2;
        continue;
      }
      i++;
    }
    // 保留:最后一帧起始之后的残留(不完整帧)
    final keepFrom = start >= 0 ? start : bytes.length;
    final rest = bytes.sublist(keepFrom);
    _buffer.clear();
    if (rest.isNotEmpty) _buffer.add(rest);
    return frames;
  }

  /// 缓冲中残留字节数(调试/测试用)。
  int get bufferedLength => _buffer.length;

  /// 清空缓冲(预览会话重启时;幂等)。
  void clear() {
    _buffer.clear();
  }
}
