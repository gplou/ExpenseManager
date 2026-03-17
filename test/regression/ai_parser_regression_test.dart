import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/features/transactions/data/ai_response_parser.dart';

/// Regression tests for AI response parsing.
///
/// These document real-world edge cases from Gemini/AI responses
/// that previously caused parsing failures.
void main() {
  group('AI response parsing regression', () {
    test('handles response with extra whitespace and newlines', () {
      const raw = '\n\n  ```json\n  {"amount": 15.50, "type": "expense"}  \n```\n\n';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['amount'], 15.50);
    });

    test('handles response with JSON code fence (uppercase)', () {
      const raw = '```JSON\n{"amount": 10}\n```';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['amount'], 10);
    });

    test('handles clean JSON without any wrapping', () {
      const raw = '{"amount": 5, "type": "income", "category": "Salario"}';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['category'], 'Salario');
    });

    test('handles response that is just empty code fences', () {
      const raw = '```json\n\n```';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNull);
    });

    test('handles response with unicode characters in values', () {
      const raw = '{"amount": 20, "category": "Educación", "description": "Café"}';
      final result = AiResponseParser.parseJsonResponse(raw);
      expect(result, isNotNull);
      expect(result!['category'], 'Educación');
      expect(result['description'], 'Café');
    });

    test('handles decimal amounts with various formats', () {
      // Some AI models return integers, some return floats
      final int1 = AiResponseParser.parseJsonResponse('{"amount": 10}');
      expect(int1!['amount'], 10);

      final float1 = AiResponseParser.parseJsonResponse('{"amount": 10.0}');
      expect(float1!['amount'], 10.0);

      final float2 = AiResponseParser.parseJsonResponse('{"amount": 10.99}');
      expect(float2!['amount'], 10.99);
    });

    test('returns null for completely invalid response', () {
      expect(AiResponseParser.parseJsonResponse('I cannot parse this'), isNull);
      expect(AiResponseParser.parseJsonResponse('Error: invalid input'), isNull);
    });

    test('returns null for null/empty response', () {
      expect(AiResponseParser.parseJsonResponse(null), isNull);
      expect(AiResponseParser.parseJsonResponse(''), isNull);
      expect(AiResponseParser.parseJsonResponse('   '), isNull);
    });
  });
}
