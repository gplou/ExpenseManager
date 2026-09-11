import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter test` renders every glyph as a solid block by default (deliberate,
/// for speed/determinism) — real pixels are only what golden tests need. This
/// loads the two bundled Inter weights before any test in this directory runs,
/// so the goldens show the actual typeface instead of placeholder boxes.
/// Scoped to `test/golden/` only: everywhere else keeps the fast default.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadWeight(String family, String asset) async {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load(asset).then((d) => d));
    await loader.load();
  }

  await loadWeight('Inter', 'assets/fonts/Inter-Regular.ttf');
  await loadWeight('Inter', 'assets/fonts/Inter-Medium.ttf');
  // Note: Phosphor icon glyphs still render as placeholder boxes here —
  // `flutter test`'s asset bundle doesn't expose the icon package's bundled
  // font the way a real app build does. Icons were verified separately on a
  // real device/simulator; these goldens exist to catch typography/color/
  // layout regressions, not icon glyph shapes.

  await testMain();
}
