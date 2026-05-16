import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/widgets/numeric_keypad.dart';

void main() {
  group('AmountKeypadController', () {
    group('digit input', () {
      test('starts empty when no initial value', () {
        final c = AmountKeypadController();
        expect(c.current, '');
        expect(c.previousText, isNull);
        expect(c.pendingOpSymbol, isNull);
      });

      test('starts with initial value when provided', () {
        final c = AmountKeypadController(initial: '42');
        expect(c.current, '42');
      });

      test('pressDigit appends digit to current', () {
        final c = AmountKeypadController();
        c.pressDigit('1');
        c.pressDigit('2');
        c.pressDigit('3');
        expect(c.current, '123');
      });

      test('pressDigit replaces leading zero', () {
        final c = AmountKeypadController(initial: '0');
        c.pressDigit('5');
        expect(c.current, '5');
      });
    });

    group('decimal separator', () {
      test('prepends 0 when empty', () {
        final c = AmountKeypadController();
        c.pressDecimal(',');
        expect(c.current, '0,');
      });

      test('appends decimal to existing digits', () {
        final c = AmountKeypadController(initial: '42');
        c.pressDecimal('.');
        expect(c.current, '42.');
      });

      test('ignores second decimal point', () {
        final c = AmountKeypadController(initial: '4.2');
        c.pressDecimal('.');
        expect(c.current, '4.2');
      });

      test('ignores decimal if comma already present', () {
        final c = AmountKeypadController(initial: '4,2');
        c.pressDecimal('.');
        expect(c.current, '4,2');
      });
    });

    group('backspace', () {
      test('removes last character', () {
        final c = AmountKeypadController(initial: '123');
        c.backspace();
        expect(c.current, '12');
      });

      test('does nothing on empty when no pending op', () {
        final c = AmountKeypadController();
        c.backspace();
        expect(c.current, '');
        expect(c.previousText, isNull);
      });

      test('cancels pending op when current is empty', () {
        final c = AmountKeypadController(initial: '10');
        c.pressAdd();
        expect(c.pendingOpSymbol, '+');
        expect(c.current, '');
        c.backspace();
        expect(c.pendingOpSymbol, isNull);
        expect(c.current, '10');
        expect(c.previousText, isNull);
      });
    });

    group('addition', () {
      test('pressAdd sets previous and clears current', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        expect(c.previousText, '5');
        expect(c.pendingOpSymbol, '+');
        expect(c.current, '');
      });

      test('chains additions by resolving and updating previous', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        c.pressDigit('3');
        c.pressAdd();
        expect(c.previousText, '8');
        expect(c.pendingOpSymbol, '+');
      });

      test('pressEquals after addition resolves to sum', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        c.pressDigit('3');
        c.pressEquals();
        expect(c.current, '8');
        expect(c.previousText, isNull);
        expect(c.pendingOpSymbol, isNull);
      });
    });

    group('subtraction', () {
      test('pressSubtract sets previous and clears current', () {
        final c = AmountKeypadController(initial: '10');
        c.pressSubtract();
        expect(c.previousText, '10');
        expect(c.pendingOpSymbol, '−');
        expect(c.current, '');
      });

      test('pressEquals after subtraction resolves to difference', () {
        final c = AmountKeypadController(initial: '10');
        c.pressSubtract();
        c.pressDigit('4');
        c.pressEquals();
        expect(c.current, '6');
      });

      test('chains subtractions', () {
        final c = AmountKeypadController(initial: '20');
        c.pressSubtract();
        c.pressDigit('5');
        c.pressSubtract();
        expect(c.previousText, '15');
        c.pressDigit('3');
        c.pressEquals();
        expect(c.current, '12');
      });
    });

    group('resolve', () {
      test('returns current value when no pending op', () {
        final c = AmountKeypadController(initial: '42');
        expect(c.resolve(), 42.0);
      });

      test('returns null when current is invalid and no previous', () {
        final c = AmountKeypadController();
        expect(c.resolve(), isNull);
      });

      test('returns previous when current empty but pending op exists', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        expect(c.resolve(), 5.0);
      });

      test('accepts comma as decimal separator', () {
        final c = AmountKeypadController(initial: '1,5');
        expect(c.resolve(), 1.5);
      });
    });

    group('setValue & clear', () {
      test('setValue replaces current and clears state', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        c.setValue(99.0);
        expect(c.current, '99');
        expect(c.previousText, isNull);
        expect(c.pendingOpSymbol, isNull);
      });

      test('setValue formats decimal with up to 2 places', () {
        final c = AmountKeypadController();
        c.setValue(12.5);
        expect(c.current, '12.5');
      });

      test('setValue formats integer without decimals', () {
        final c = AmountKeypadController();
        c.setValue(50.0);
        expect(c.current, '50');
      });

      test('setValue trims trailing zeros', () {
        final c = AmountKeypadController();
        c.setValue(12.10);
        expect(c.current, '12.1');
      });

      test('clear resets everything', () {
        final c = AmountKeypadController(initial: '5');
        c.pressAdd();
        c.pressDigit('3');
        c.clear();
        expect(c.current, '');
        expect(c.previousText, isNull);
        expect(c.pendingOpSymbol, isNull);
      });
    });

    group('listener notifications', () {
      test('notifies on every mutation', () {
        final c = AmountKeypadController();
        int notifyCount = 0;
        c.addListener(() => notifyCount++);

        c.pressDigit('1');
        c.pressDigit('2');
        c.pressDecimal('.');
        c.pressAdd();
        c.pressDigit('5');
        c.pressEquals();
        c.clear();
        c.setValue(10);

        expect(notifyCount, greaterThanOrEqualTo(7));
      });
    });

    group('edge cases', () {
      test('pressEquals with no operands is a no-op', () {
        final c = AmountKeypadController();
        c.pressEquals();
        expect(c.current, '');
      });

      test('pressAdd with no operand is a no-op', () {
        final c = AmountKeypadController();
        c.pressAdd();
        expect(c.pendingOpSymbol, isNull);
        expect(c.previousText, isNull);
      });
    });
  });
}
