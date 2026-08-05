import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/presentation/image_control_screen.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import '../../fixtures/fake_image_probe_port.dart';

void main() {
  testWidgets('debug menu', (tester) async {
    final probe = FakeImageProbePort(width: 640, height: 480);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageProbePortProvider.overrideWithValue(probe),
          appLoggerProvider.overrideWithValue(AppLogger()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImageControlScreen(
                        path: '/img/a.png',
                        index: 0,
                        canvasW: 640,
                        canvasH: 480,
                        initial: null,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    debugPrint('--- all Text after opening menu ---');
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      debugPrint('TEXT: [${w.data}]');
    }
  });
}
