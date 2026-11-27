import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual QA screenshots, written to `.dart_tool/experience_qa/` only when
/// tests run with `--dart-define=UPDATE_FIVE_SCREENSHOTS=true`.
const qaShots = bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS');

/// Loads the real app fonts so screenshots show text instead of boxes.
Future<void> loadQaFonts() async {
  if (!qaShots) return;
  for (final (family, path) in [
    ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
    ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(path))).load();
  }
}

/// Writes the [RepaintBoundary] under [boundary] to `<name>.png`.
Future<void> captureQa(WidgetTester t, GlobalKey boundary, String name) async {
  if (!qaShots) return;
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/experience_qa/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
