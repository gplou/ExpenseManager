import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

/// Builders for stubbing `SupabaseClient.functions.invoke(...)` calls.
///
/// The Supabase SDK's [FunctionResponse] doesn't expose a const/public
/// constructor we can rely on across versions, so we use a `Mock`
/// implementation here.
///
/// Typical usage:
/// ```dart
/// final supabase = MockSupabaseClient();
/// final functions = MockFunctionsClient();
/// when(() => supabase.functions).thenReturn(functions);
///
/// stubFunctionInvoke(
///   functions,
///   functionName: 'parse-voice-transaction',
///   response: okFunctionResponse({'result': '{"amount":12.5}'}),
/// );
/// ```
///
/// **Note:** the stub matches only on the positional [functionName] and the
/// `body` named arg, since those are the only parameters our code passes.
/// If you need to assert other arguments (`headers`, `region`, etc.),
/// use `verify(() => functions.invoke(...))` directly with your own matchers.
class _MockFunctionResponse extends Mock implements FunctionResponse {}

/// Builds a [FunctionResponse] mock with status 200 and the given JSON payload.
FunctionResponse okFunctionResponse(Map<String, dynamic> data) {
  final response = _MockFunctionResponse();
  when(() => response.status).thenReturn(200);
  when(() => response.data).thenReturn(data);
  return response;
}

/// Builds a [FunctionResponse] mock with an arbitrary [status] and [data].
FunctionResponse functionResponseWith({
  required int status,
  Object? data,
}) {
  final response = _MockFunctionResponse();
  when(() => response.status).thenReturn(status);
  when(() => response.data).thenReturn(data);
  return response;
}

/// Stubs `functions.invoke(functionName, body: <any>)` to return [response].
///
/// If [functionName] is null, the stub matches any function name.
void stubFunctionInvoke(
  MockFunctionsClient functions, {
  String? functionName,
  required FunctionResponse response,
}) {
  when(
    () => functions.invoke(
      functionName ?? any(),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async => response);
}

/// Stubs `functions.invoke(...)` to throw [error]. Use for testing
/// network/timeout error paths.
void stubFunctionInvokeError(
  MockFunctionsClient functions, {
  String? functionName,
  required Object error,
}) {
  when(
    () => functions.invoke(
      functionName ?? any(),
      body: any(named: 'body'),
    ),
  ).thenThrow(error);
}
