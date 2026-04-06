import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/widgets/ad_banner_footer.dart';

void main() {
  group('AdBannerFooter', () {
    testWidgets('renders SizedBox.shrink placeholder', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdBannerFooter()),
          ),
        ),
      );

      // The widget currently renders a SizedBox.shrink
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });
  });
}
