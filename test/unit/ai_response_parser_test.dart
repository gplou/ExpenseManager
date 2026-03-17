import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/data/ai_response_parser.dart';

void main() {
  group('AiResponseParser.parseJsonResponse', () {
    test('returns null for null input', () {
      expect(AiResponseParser.parseJsonResponse(null), isNull);
    });

    test('returns null for empty string', () {
      expect(AiResponseParser.parseJsonResponse(''), isNull);
    });

    test('parses raw JSON', () {
      const raw = '{"amount": 10.5, "type": "expense"}';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['amount'], 10.5);
      expect(result['type'], 'expense');
    });

    test('strips ```json code fence', () {
      const raw = '```json\n{"amount": 20}\n```';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['amount'], 20);
    });

    test('strips ``` code fence without language tag', () {
      const raw = '```\n{"amount": 30}\n```';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['amount'], 30);
    });

    test('returns null for invalid JSON', () {
      expect(AiResponseParser.parseJsonResponse('not json'), isNull);
    });

    test('returns null for code fence with invalid JSON inside', () {
      expect(AiResponseParser.parseJsonResponse('```json\nnot json\n```'), isNull);
    });

    test('handles whitespace around code fences', () {
      const raw = '  ```json  \n  {"key": "value"}  \n  ```  ';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['key'], 'value');
    });
  });
}
