import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/shared/platform/android_media_store.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';

/// [AndroidMediaStoreSaver] 通道契约测试:参数透传、结果解析、异常映射。
///
/// 原生逻辑(MediaStore/FileProvider)宿主无法测,此处锁定 Dart 侧桥契约。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.chameleongif.chameleon_gif/media_store');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock(Map<String, dynamic>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  group('AndroidMediaStoreSaver.saveToGallery', () {
    test('参数透传 + saved 结果解析', () async {
      MethodCall? received;
      mock((call) {
        received = call;
        return {
          'status': 'saved',
          'displayPath': 'Pictures/GIFForge/demo.gif',
          'uri': 'content://media/external/images/media/1',
        };
      });

      final r = await const AndroidMediaStoreSaver().saveToGallery(
        '/cache/out.gif',
        displayName: 'demo.gif',
      );
      expect(received?.method, 'saveToGallery');
      expect(received?.arguments, {
        'path': '/cache/out.gif',
        'displayName': 'demo.gif',
      });
      expect(r.status, GallerySaveStatus.saved);
      expect(r.displayPath, 'Pictures/GIFForge/demo.gif');
      expect(r.uri, 'content://media/external/images/media/1');
    });

    test('failed 结果解析(中文提示)', () async {
      mock((call) => {'status': 'failed', 'message': '当前系统版本过低,请使用系统分享保存'});

      final r = await const AndroidMediaStoreSaver().saveToGallery('/x.gif');
      expect(r.status, GallerySaveStatus.failed);
      expect(r.message, '当前系统版本过低,请使用系统分享保存');
    });

    test('未知状态 → unsupported', () async {
      mock((call) => {'status': 'weird'});

      final r = await const AndroidMediaStoreSaver().saveToGallery('/x.gif');
      expect(r.status, GallerySaveStatus.unsupported);
    });

    test('PlatformException → failed', () async {
      mock((call) => throw PlatformException(code: 'err', message: 'boom'));

      final r = await const AndroidMediaStoreSaver().saveToGallery('/x.gif');
      expect(r.status, GallerySaveStatus.failed);
      expect(r.message, contains('boom'));
    });

    test('MissingPluginException → unsupported(桌面宿主)', () async {
      mock((call) => throw MissingPluginException());

      final r = await const AndroidMediaStoreSaver().saveToGallery('/x.gif');
      expect(r.status, GallerySaveStatus.unsupported);
    });
  });

  group('AndroidMediaStoreSaver.openGallery/shareFile', () {
    test('openGallery 参数透传;MissingPluginException 静默', () async {
      MethodCall? received;
      mock((call) {
        received = call;
        return null;
      });

      await const AndroidMediaStoreSaver().openGallery(
        uri: 'content://media/1',
      );
      expect(received?.method, 'openGallery');
      expect(received?.arguments, {'uri': 'content://media/1'});

      mock((call) => throw MissingPluginException());
      await const AndroidMediaStoreSaver().openGallery(uri: null); // 不抛
    });

    test('shareFile 参数透传;异常静默', () async {
      MethodCall? received;
      mock((call) {
        received = call;
        return null;
      });

      await const AndroidMediaStoreSaver().shareFile('/cache/out.gif');
      expect(received?.method, 'shareFile');
      expect(received?.arguments, {'path': '/cache/out.gif'});

      mock((call) => throw PlatformException(code: 'x'));
      await const AndroidMediaStoreSaver().shareFile('/x.gif'); // 不抛
    });
  });
}
