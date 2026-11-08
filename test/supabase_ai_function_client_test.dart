import 'package:flutter_test/flutter_test.dart';
import 'package:nutrifridge/models/nutrition_data.dart';
import 'package:nutrifridge/services/ai/supabase_ai_function_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SupabaseAiFunctionClient.resetTestState();
    MockDataRepository.forceInMemoryForTesting = false;
  });

  tearDown(() {
    SupabaseAiFunctionClient.resetTestState();
  });

  group('Session Handling & Proactive Refresh (120s Window)', () {
    test('1. Valid session with > 120s remaining does not trigger refresh', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'valid.token.jwt';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 300; // 300s > 120s

      bool refreshCalled = false;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCalled = true;
        return 'refreshed.token';
      };

      final token = await SupabaseAiFunctionClient.getValidAccessToken();

      expect(token, equals('valid.token.jwt'));
      expect(refreshCalled, isFalse);
    });

    test('2. Session expiring in <= 120s triggers proactive refresh', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'near.expiry.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 60; // 60s <= 120s

      bool refreshCalled = false;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCalled = true;
        return 'fresh.refreshed.token';
      };

      final token = await SupabaseAiFunctionClient.getValidAccessToken();

      expect(token, equals('fresh.refreshed.token'));
      expect(refreshCalled, isTrue);
    });

    test('3. Already expired session triggers refresh before invocation', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'expired.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now - 30; // expired 30s ago

      bool refreshCalled = false;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCalled = true;
        return 'new.fresh.token';
      };

      final token = await SupabaseAiFunctionClient.getValidAccessToken();

      expect(token, equals('new.fresh.token'));
      expect(refreshCalled, isTrue);
    });

    test('4. Missing session throws AuthenticationRequiredException', () async {
      SupabaseAiFunctionClient.testHasSession = false;

      expect(
        () => SupabaseAiFunctionClient.getValidAccessToken(),
        throwsA(isA<AuthenticationRequiredException>()),
      );
    });

    test('5. Refresh failure throws SessionRefreshException', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'expired.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now - 10;
      SupabaseAiFunctionClient.simulateRefreshFailure = true;

      expect(
        () => SupabaseAiFunctionClient.getValidAccessToken(),
        throwsA(isA<SessionRefreshException>()),
      );
    });

    test('6 & 7. Empty refreshed access token throws SessionRefreshException', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'expired.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now - 10;

      SupabaseAiFunctionClient.testSessionRefresher = () async {
        return ''; // empty token returned
      };

      expect(
        () => SupabaseAiFunctionClient.getValidAccessToken(),
        throwsA(isA<SessionRefreshException>()),
      );
    });
  });

  group('Concurrency Protection', () {
    test('Simultaneous requests share a single in-flight refresh operation', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'near.expiry.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 30; // <= 120s

      int refreshCount = 0;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'concurrent.refreshed.token';
      };

      // Launch 3 requests concurrently
      final futures = [
        SupabaseAiFunctionClient.getValidAccessToken(),
        SupabaseAiFunctionClient.getValidAccessToken(),
        SupabaseAiFunctionClient.getValidAccessToken(),
      ];

      final results = await Future.wait(futures);

      expect(results[0], equals('concurrent.refreshed.token'));
      expect(results[1], equals('concurrent.refreshed.token'));
      expect(results[2], equals('concurrent.refreshed.token'));

      // Crucial: Only ONE refresh operation was dispatched!
      expect(refreshCount, equals(1));
    });
  });

  group('Request Headers & Invocation', () {
    test('8 & 10 & 11. Fresh JWT and apikey injected into headers; body preserved', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'guaranteed.fresh.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 600;

      Map<String, String>? capturedHeaders;
      dynamic capturedBody;

      SupabaseAiFunctionClient.testFunctionInvoker = (fn, body, headers) async {
        capturedHeaders = headers;
        capturedBody = body;
        return FunctionResponse(
          data: {
            'ok': true,
            'action': 'meal_recommendation',
            'assistantMessage': 'Recipe ready',
            'meal': {'name': 'Toast'},
          },
          status: 200,
        );
      };

      final testBody = {
        'message': 'Create recipe',
        'recipeMode': 'selected_ingredients',
        'selectedInventoryItemIds': ['item-1', 'item-2'],
      };

      final response = await SupabaseAiFunctionClient.invokeAiFunction(
        body: testBody,
      );

      expect(response['ok'], isTrue);
      expect(capturedHeaders, isNotNull);
      expect(capturedHeaders!['Authorization'], equals('Bearer guaranteed.fresh.token'));
      expect(capturedBody, equals(testBody));
    });
  });

  group('Gateway 401 Recovery & Retry', () {
    test('12-15. First request receives UNAUTHORIZED_LEGACY_JWT -> refreshes -> retries once and succeeds', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'stale.legacy.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 600; // appears unexpired locally

      int refreshCalls = 0;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCalls++;
        return 'modern.es256.fresh.token';
      };

      int callCount = 0;
      final tokensUsed = <String>[];

      SupabaseAiFunctionClient.testFunctionInvoker = (fn, body, headers) async {
        callCount++;
        final token = headers!['Authorization']!.replaceFirst('Bearer ', '');
        tokensUsed.add(token);

        if (callCount == 1) {
          // Gateway rejects with UNAUTHORIZED_LEGACY_JWT
          throw const FunctionException(
            status: 401,
            details: '{"code":"UNAUTHORIZED_LEGACY_JWT","message":"Invalid JWT"}',
            reasonPhrase: 'Unauthorized',
          );
        }

        // Retry with refreshed token succeeds
        return FunctionResponse(
          data: {
            'ok': true,
            'action': 'meal_recommendation',
            'assistantMessage': 'Delicious recipe generated after refresh',
            'meal': {'name': 'Cinnamon French Toast'},
          },
          status: 200,
        );
      };

      final response = await SupabaseAiFunctionClient.invokeAiFunction(
        body: {'message': 'Cook with bread and apples'},
      );

      expect(response['ok'], isTrue);
      expect(response['assistantMessage'], contains('Delicious recipe generated'));
      expect(callCount, equals(2)); // exactly 1 retry
      expect(tokensUsed[0], equals('stale.legacy.token'));
      expect(tokensUsed[1], equals('modern.es256.fresh.token'));
      expect(refreshCalls, equals(1));
    });

    test('16 & 17. Failed retry stops after exactly 1 retry and returns specific error', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'stale.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 600;

      SupabaseAiFunctionClient.testSessionRefresher = () async {
        return 'fresh.token';
      };

      int callCount = 0;
      SupabaseAiFunctionClient.testFunctionInvoker = (fn, body, headers) async {
        callCount++;
        // Both initial and retry fail with 401
        throw const FunctionException(
          status: 401,
          details: '{"code":"UNAUTHORIZED_LEGACY_JWT","message":"Invalid JWT"}',
          reasonPhrase: 'Unauthorized',
        );
      };

      final response = await SupabaseAiFunctionClient.invokeAiFunction(
        body: {'message': 'test'},
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], equals('NutriFridge could not verify your session. Please sign in again.'));
      // Exactly 2 attempts (initial + 1 retry)
      expect(callCount, equals(2));
    });

    test('18. Non-authentication errors (400, 404, 429, 500) are NOT retried', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      SupabaseAiFunctionClient.testHasSession = true;
      SupabaseAiFunctionClient.testCurrentSessionToken = 'valid.token';
      SupabaseAiFunctionClient.testExpiresAtOverride = now + 600;

      int refreshCalls = 0;
      SupabaseAiFunctionClient.testSessionRefresher = () async {
        refreshCalls++;
        return 'new.token';
      };

      int callCount = 0;
      SupabaseAiFunctionClient.testFunctionInvoker = (fn, body, headers) async {
        callCount++;
        throw const FunctionException(
          status: 400,
          details: '{"error":{"code":"INVALID_UUID_SYNTAX","message":"Invalid UUID"}}',
        );
      };

      final response = await SupabaseAiFunctionClient.invokeAiFunction(
        body: {'message': 'test'},
      );

      expect(response['ok'], isFalse);
      expect(response['assistantMessage'], contains('ingredient IDs are invalid'));
      // Must not retry non-auth errors
      expect(callCount, equals(1));
      expect(refreshCalls, equals(0));
    });
  });

  group('Safe Token Metadata Inspection', () {
    test('inspectTokenMetadata parses claims without throwing or exposing signature', () {
      const testJwt = 'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3OTQxNDY1ODgsImlhdCI6MTc5NDE0Mjk4OCwic3ViIjoidXNlcl8xMjMifQ.signature_bytes';

      final meta = SupabaseAiFunctionClient.inspectTokenMetadata(testJwt);

      expect(meta, isNotNull);
      expect(meta!['alg'], equals('ES256'));
      expect(meta['exp'], equals(1794146588));
      expect(meta['iat'], equals(1794142988));
      expect(meta.containsKey('signature'), isFalse);
    });

    test('inspectTokenMetadata handles malformed token string gracefully', () {
      final meta = SupabaseAiFunctionClient.inspectTokenMetadata('not_a_valid_jwt');
      expect(meta, isNull);
    });
  });
}
