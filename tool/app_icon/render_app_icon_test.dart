// Renders the app icon and splash artwork into assets/.
//
// This is not one of the app's tests (it lives in tool/, so `flutter test`
// skips it). Run it after changing app_icon_painter.dart:
//
//   flutter test tool/app_icon/render_app_icon_test.dart --update-goldens
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_icon_painter.dart';

Future<void> render(
  WidgetTester tester, {
  required String file,
  required double size,
  required AppIconPainter painter,
}) async {
  tester.view.physicalSize = Size.square(size);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: painter),
        ),
      ),
    ),
  );
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('../../assets/$file'),
  );
}

void main() {
  testWidgets('app icon (iPhone, web, older Android)', (tester) async {
    await render(
      tester,
      file: 'icon/app_icon.png',
      size: 1024,
      painter: const AppIconPainter(),
    );
  });

  testWidgets('Android adaptive icon: green background layer', (tester) async {
    await render(
      tester,
      file: 'icon/app_icon_background.png',
      size: 1024,
      painter: const AppIconPainter(scale: 0),
    );
  });

  testWidgets('Android adaptive icon: house layer (smaller, see-through)', (
    tester,
  ) async {
    // Android crops icons to circles, squircles, etc. Keeping the house
    // inside the middle ~60% means nothing important gets cut off.
    await render(
      tester,
      file: 'icon/app_icon_foreground.png',
      size: 1024,
      painter: const AppIconPainter(withBackground: false, scale: 0.6),
    );
  });

  testWidgets('splash: the house on a see-through background', (tester) async {
    await render(
      tester,
      file: 'splash/splash_logo.png',
      size: 1024,
      painter: const AppIconPainter(withBackground: false, scale: 0.9),
    );
  });

  testWidgets('splash on Android 12+: house inside the round safe area', (
    tester,
  ) async {
    await render(
      tester,
      file: 'splash/splash_logo_android12.png',
      size: 1152,
      painter: const AppIconPainter(withBackground: false, scale: 0.6),
    );
  });
}
