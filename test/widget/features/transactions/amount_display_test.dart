import 'package:flutter_test/flutter_test.dart';

import 'package:expense_manager/features/transactions/presentation/widgets/add_transaction_widgets.dart';

void main() {
  group('AmountDisplay.rollingText', () {
    test('usa los mismos decimales que el texto final', () {
      // Antes pasaba por "6.00" y al acabar saltaba a "17.5".
      expect(AmountDisplay.rollingText(6, '17.5'), '6.0');
      expect(AmountDisplay.rollingText(6, '17.50'), '6.00');
      expect(AmountDisplay.rollingText(6.4, '17'), '6');
    });

    test('respeta el separador decimal del teclado', () {
      expect(AmountDisplay.rollingText(6.25, '17,5'), '6,3');
      expect(AmountDisplay.rollingText(6.25, '17,50'), '6,25');
    });
  });
}
