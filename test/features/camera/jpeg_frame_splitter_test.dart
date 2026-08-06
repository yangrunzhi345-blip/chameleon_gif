import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/camera/application/jpeg_frame_splitter.dart';

/// JPEG 帧分割器(ffmpeg image2pipe mjpeg 流切帧;SOI/EOI 标记)。
void main() {
  Uint8List jpeg(int seed) => Uint8List.fromList([
    0xFF, 0xD8, // SOI
    seed & 0xFF, 0x01, 0x02,
    0xFF, 0xD9, // EOI
  ]);

  test('单块完整帧:切出 1 帧', () {
    final splitter = JpegFrameSplitter();
    final frames = splitter.addChunk(jpeg(1));
    expect(frames, hasLength(1));
    expect(frames.single, jpeg(1));
    expect(splitter.bufferedLength, 0);
  });

  test('多帧拼接:一次切出全部', () {
    final splitter = JpegFrameSplitter();
    final frames = splitter.addChunk(
      Uint8List.fromList([...jpeg(1), ...jpeg(2), ...jpeg(3)]),
    );
    expect(frames, hasLength(3));
    expect(frames[0], jpeg(1));
    expect(frames[2], jpeg(3));
  });

  test('跨块切帧:帧被字节块拆分仍完整还原', () {
    final splitter = JpegFrameSplitter();
    final raw = Uint8List.fromList([...jpeg(1), ...jpeg(2)]);
    final first = splitter.addChunk(raw.sublist(0, 3));
    expect(first, isEmpty, reason: '首块无完整帧');
    final rest = splitter.addChunk(raw.sublist(3));
    expect(rest, hasLength(2), reason: '补齐后切出两帧');
    expect(rest[0], jpeg(1));
    expect(rest[1], jpeg(2));
  });

  test('熵数据中的 0xFF 填充字节不误判(0xFF00)', () {
    final splitter = JpegFrameSplitter();
    final raw = Uint8List.fromList([
      0xFF, 0xD8,
      0xFF, 0x00, // byte stuffing(非标记)
      0x12, 0x34,
      0xFF, 0xD9,
    ]);
    final frames = splitter.addChunk(raw);
    expect(frames, hasLength(1));
    expect(frames.single, raw);
  });

  test('不完整尾帧暂存,补齐后输出(EOI 跨块拆分)', () {
    final splitter = JpegFrameSplitter();
    final raw = jpeg(9); // [FF D8 09 01 02 FF D9]
    // 切在 EOI 中间:首块含 EOI 的 FF,补齐只需 D9
    final head = splitter.addChunk(raw.sublist(0, raw.length - 1));
    expect(head, isEmpty);
    expect(splitter.bufferedLength, raw.length - 1);
    final tail = splitter.addChunk(Uint8List.fromList([0xD9]));
    expect(tail, hasLength(1));
    expect(tail.single, raw);
  });

  test('空块无输出;clear 清空缓冲', () {
    final splitter = JpegFrameSplitter();
    splitter.addChunk(jpeg(1).sublist(0, 2));
    expect(splitter.bufferedLength, greaterThan(0));
    splitter.clear();
    expect(splitter.bufferedLength, 0);
    expect(splitter.addChunk(Uint8List(0)), isEmpty);
  });
}
