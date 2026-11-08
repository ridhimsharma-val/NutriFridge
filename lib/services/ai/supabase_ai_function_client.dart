import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../../models/nutrition_data.dart';

/// Exception thrown when no active authenticated session exists.
class AuthenticationRequiredException implements Exception {
  final String message;
  const AuthenticationRequiredException([
    this.message = 'Please sign in again to continue.',
  ]);

  @override
  String toString() => message;
}

/// Exception thrown when a session refresh operation fails.
class SessionRefreshException implements Exception {
  final String message;
  const SessionRefreshException([
    this.message = 'Your session could not be refreshed. Please sign in again.',
  ]);

  @override
  String toString() => message;
}

/// Centralized, concurrency-safe client for invoking the Supabase Edge Function `nutrifridge-ai`.
///
/// Responsibilities:
/// 1. Proactive session validation: checks expiration with a 120-second safety window.
/// 2. Concurrency protection: merges parallel refresh requests onto a single in-flight Future.
/// 3. Fresh token propagation: always injects the latest resolved access token into `Authorization: Bearer <token>`.
/// 4. Gateway 401 recovery: performs exactly one controlled forced-refresh retry on authentication failure.
/// 5. Safe token metadata inspection: logs algorithm and expiration claims without exposing credentials.
/// 6. Actionable user error mapping: preserves distinct errors without generic masking.
class SupabaseAiFunctionClient {
  static const String defaultFunctionName = 'nutrifridge-ai';
  static const Duration defaultTimeout = Duration(seconds: 90);

  /// In-flight refresh operation shared across concurrent callers to prevent token rotation conflicts.
  static Future<String>? _ongoingRefresh;

  /// Optional mock handler for offline unit and widget test suites.
  static Future<Map<String, dynamic>> Function(Map<String, dynamic>)? mockHandler;

  /// Custom SupabaseClient override for testing.
  static SupabaseClient? customClientOverride;

  // -------------------------------------------------------------
  // Test Hooks (for deterministic unit testing without external mocks)
  // -------------------------------------------------------------
  @visibleForTesting
  static bool? testHasSession;

  @visibleForTesting
  static String? testCurrentSessionToken;

  @visibleForTesting
  static int? testExpiresAtOverride;

  @visibleForTesting
  static bool simulateRefreshFailure = false;

  @visibleForTesting
  static int testRetryCount = 0;

  @visibleForTesting
  static Future<String> Function()? testSessionRefresher;

  @visibleForTesting
  static Future<FunctionResponse> Function(
    String functionName,
    Map<String, dynamic> body,
    Map<String, String>? headers,
  )? testFunctionInvoker;

  /// Resets all test hooks back to default production state.
  static void resetTestState() {
    testHasSession = null;
    testCurrentSessionToken = null;
    testExpiresAtOverride = null;
    simulateRefreshFailure = false;
    testRetryCount = 0;
    testSessionRefresher = null;
    testFunctionInvoker = null;
    mockHandler = null;
    customClientOverride = null;
    _ongoingRefresh = null;
  }

  /// Safely extracts and logs token metadata (alg, exp, iat) without logging
  /// the token itself, signature, or credentials.
  static Map<String, dynamic>? inspectTokenMetadata(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final headerStr = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerStr) as Map<String, dynamic>;

      final payloadStr = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

      final alg = header['alg']?.toString();
      final exp = payload['exp'] is num ? (payload['exp'] as num).toInt() : null;
      final iat = payload['iat'] is num ? (payload['iat'] as num).toInt() : null;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final remaining = exp != null ? (exp - now) : null;

      debugPrint(
        '[SupabaseAiFunctionClient] Token metadata: alg=$alg, iat=$iat, exp=$exp (remaining: ${remaining}s)',
      );

      return {
        'alg': alg,
        'iat': iat,
        'exp': exp,
        'remainingSeconds': remaining,
      };
    } catch (e) {
      debugPrint('[SupabaseAiFunctionClient] Unable to parse token metadata: $e');
      return null;
    }
  }

  /// Resolves the effective Supabase client instance.
  static SupabaseClient? _resolveClient(SupabaseClient? customClient) {
    if (customClientOverride != null) return customClientOverride;
    if (customClient != null) return customClient;
    if (SupabaseManager.isInitialized) return SupabaseManager.client;
    return null;
  }

  /// Obtains a guaranteed-valid access token.
  ///
  /// - If the token is expired or within the 120-second threshold, proactively refreshes it.
  /// - If [forceRefresh] is true (e.g. during Gateway 401 recovery), forces a refresh regardless of remaining time.
  /// - Thread-safe: concurrent calls share a single in-flight refresh Future.
  static Future<String> getValidAccessToken({
    SupabaseClient? customClient,
    bool forceRefresh = false,
  }) async {
    // 1. Check test overrides first
    if (testHasSession == false) {
      throw const AuthenticationRequiredException(
        'Please sign in again to continue.',
      );
    }

    if (testCurrentSessionToken != null) {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final int? expiresAt = testExpiresAtOverride;
      final bool isNearExpiry = expiresAt != null && (expiresAt - nowSeconds) <= 120;
      final bool isExpired = expiresAt != null && expiresAt <= nowSeconds;

      if (forceRefresh || isExpired || isNearExpiry) {
        if (_ongoingRefresh != null) {
          debugPrint('[SupabaseAiFunctionClient] Reusing in-flight session refresh operation...');
          return await _ongoingRefresh!;
        }

        final refreshFuture = _performTestRefresh();
        _ongoingRefresh = refreshFuture;

        try {
          final refreshedToken = await refreshFuture;
          return refreshedToken;
        } finally {
          _ongoingRefresh = null;
        }
      }

      final token = testCurrentSessionToken!;
      if (token.isEmpty) {
        throw const AuthenticationRequiredException(
          'Authentication token is missing. Please sign in again.',
        );
      }
      inspectTokenMetadata(token);
      return token;
    }

    final client = _resolveClient(customClient);
    if (client == null) {
      throw const AuthenticationRequiredException(
        'Please sign in to your NutriFridge account to use AI features.',
      );
    }

    final currentSession = client.auth.currentSession;
    if (currentSession == null) {
      throw const AuthenticationRequiredException(
        'Please sign in again to continue.',
      );
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int? expiresAt = testExpiresAtOverride ?? currentSession.expiresAt;
    final bool isNearExpiry = expiresAt != null && (expiresAt - nowSeconds) <= 120;
    final bool isExpired = currentSession.isExpired || (expiresAt != null && expiresAt <= nowSeconds);

    if (forceRefresh || isExpired || isNearExpiry) {
      if (_ongoingRefresh != null) {
        debugPrint('[SupabaseAiFunctionClient] Reusing in-flight session refresh operation...');
        return await _ongoingRefresh!;
      }

      final refreshFuture = _performRefresh(client);
      _ongoingRefresh = refreshFuture;

      try {
        final refreshedToken = await refreshFuture;
        return refreshedToken;
      } finally {
        _ongoingRefresh = null;
      }
    }

    final token = currentSession.accessToken;
    if (token.isEmpty) {
      throw const AuthenticationRequiredException(
        'Authentication token is missing. Please sign in again.',
      );
    }

    inspectTokenMetadata(token);
    return token;
  }

  static Future<String> _performTestRefresh() async {
    debugPrint('[SupabaseAiFunctionClient] Initiating test session refresh...');
    if (simulateRefreshFailure) {
      throw const SessionRefreshException(
        'Your session could not be refreshed. Please sign in again.',
      );
    }

    if (testSessionRefresher != null) {
      final token = await testSessionRefresher!();
      if (token.isEmpty) {
        throw const SessionRefreshException(
          'Your session could not be refreshed. Please sign in again.',
        );
      }
      testCurrentSessionToken = token;
      return token;
    }

    throw const SessionRefreshException(
      'Your session could not be refreshed. Please sign in again.',
    );
  }

  static Future<String> _performRefresh(SupabaseClient client) async {
    debugPrint('[SupabaseAiFunctionClient] Initiating proactive session refresh (120s safety window)...');

    if (simulateRefreshFailure) {
      throw const SessionRefreshException(
        'Your session could not be refreshed. Please sign in again.',
      );
    }

    try {
      final response = await client.auth.refreshSession();
      final freshSession = response.session ?? client.auth.currentSession;
      final freshToken = freshSession?.accessToken;

      if (freshToken == null || freshToken.isEmpty) {
        throw const SessionRefreshException(
          'Your session could not be refreshed. Please sign in again.',
        );
      }

      debugPrint('[SupabaseAiFunctionClient] Session successfully refreshed.');
      inspectTokenMetadata(freshToken);
      return freshToken;
    } on AuthException catch (e) {
      debugPrint('[SupabaseAiFunctionClient] Supabase AuthException during refresh: ${e.message}');
      throw SessionRefreshException(
        'Your session has expired (${e.message}). Please sign in again.',
      );
    } catch (e) {
      if (e is SessionRefreshException) rethrow;
      debugPrint('[SupabaseAiFunctionClient] Error during session refresh: $e');
      throw const SessionRefreshException(
        'Your session could not be refreshed. Please sign in again.',
      );
    }
  }

  /// Checks whether an exception represents a gateway or Edge Function authentication failure.
  static bool isAuthenticationFailure(dynamic exception) {
    if (exception is FunctionException) {
      if (exception.status == 401) return true;
      final detailsStr = (exception.details?.toString() ?? exception.reasonPhrase ?? '').toLowerCase();
      return detailsStr.contains('unauthorized_legacy_jwt') ||
          detailsStr.contains('invalid jwt') ||
          detailsStr.contains('jwt expired') ||
          detailsStr.contains('user_authentication_failed') ||
          detailsStr.contains('missing_authorization') ||
          detailsStr.contains('invalid_authorization_format');
    }

    final errStr = exception.toString().toLowerCase();
    return errStr.contains('unauthorized_legacy_jwt') ||
        errStr.contains('invalid jwt') ||
        errStr.contains('401') ||
        errStr.contains('unauthorized');
  }

  /// Dispatches an authenticated request to `nutrifridge-ai` with:
  /// 1. Proactive 120-second session refresh check
  /// 2. Fresh Authorization header injection
  /// 3. One controlled gateway 401 recovery retry
  /// 4. Structured user-friendly error mapping
  static Future<Map<String, dynamic>> invokeAiFunction({
    required Map<String, dynamic> body,
    String functionName = defaultFunctionName,
    SupabaseClient? customClient,
    Duration timeout = defaultTimeout,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? handlerOverride,
  }) async {
    testRetryCount = 0;

    // 1. Mock handler bypass (for unit tests and deterministic offline test suites)
    final effectiveMock = handlerOverride ?? mockHandler;
    if (effectiveMock != null) {
      final mockResult = await effectiveMock(body);
      return normalizeResponse(mockResult);
    }

    final client = _resolveClient(customClient);

    // 2. Reject unauthenticated requests in live mode
    if (!MockDataRepository.forceInMemoryForTesting && testHasSession == null && testCurrentSessionToken == null) {
      if (client == null || client.auth.currentSession == null) {
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': 'Please sign in to your NutriFridge account to use AI features.',
          'error': 'User not authenticated',
          'requiresConfirmation': false,
        };
      }
    }

    // 3. Execution loop with exactly one controlled Gateway 401 recovery retry
    for (int attempt = 0; attempt <= 1; attempt++) {
      final bool isRetry = attempt > 0;
      if (isRetry) {
        testRetryCount++;
      }

      final String token;
      try {
        token = await getValidAccessToken(
          customClient: client,
          forceRefresh: isRetry, // force fresh token if recovering from 401
        );
      } on AuthenticationRequiredException catch (e) {
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': e.message,
          'error': 'AuthenticationRequiredException: ${e.message}',
          'requiresConfirmation': false,
        };
      } on SessionRefreshException catch (e) {
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': e.message,
          'error': 'SessionRefreshException: ${e.message}',
          'requiresConfirmation': false,
        };
      } catch (e) {
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': 'Unable to verify authentication. Please sign in again.',
          'error': e.toString(),
          'requiresConfirmation': false,
        };
      }

      final invocationHeaders = <String, String>{
        'Authorization': 'Bearer $token',
      };
      if (SupabaseConfig.isConfigured && SupabaseConfig.supabasePublishableKey.isNotEmpty) {
        invocationHeaders['apikey'] = SupabaseConfig.supabasePublishableKey;
      }

      final stopwatch = Stopwatch()..start();
      try {
        final FunctionResponse response;
        if (testFunctionInvoker != null) {
          response = await testFunctionInvoker!(functionName, body, invocationHeaders);
        } else {
          response = await client!.functions
              .invoke(
                functionName,
                body: body,
                headers: invocationHeaders,
              )
              .timeout(timeout);
        }

        stopwatch.stop();
        debugPrint(
          '[SupabaseAiFunctionClient] Edge function returned status ${response.status} in ${stopwatch.elapsedMilliseconds}ms',
        );

        final dynamic data = response.data;
        if (data == null) {
          return {
            'ok': false,
            'success': false,
            'action': 'error',
            'assistantMessage': 'Received an empty response from NutriFridge AI. Please tap retry.',
            'error': 'Response data was null',
            'requiresConfirmation': false,
          };
        }

        return normalizeResponse(data);
      } on FunctionException catch (e) {
        stopwatch.stop();
        debugPrint(
          '[SupabaseAiFunctionClient] FunctionException (${e.status}) on attempt $attempt: ${e.details}',
        );

        final bool isAuthError = isAuthenticationFailure(e);

        // Gateway 401 Recovery: If 401 and attempt == 0, retry ONCE with forced session refresh
        if (isAuthError && attempt == 0) {
          debugPrint(
            '[SupabaseAiFunctionClient] Gateway 401 / UNAUTHORIZED_LEGACY_JWT encountered. Attempting one forced session refresh and retry...',
          );
          continue;
        }

        final friendlyMessage = _mapFunctionExceptionToMessage(e, isAfterRetry: isRetry);
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': friendlyMessage,
          'error': 'FunctionException (${e.status}): ${e.details ?? e.reasonPhrase}',
          'requiresConfirmation': false,
        };
      } on TimeoutException catch (e) {
        stopwatch.stop();
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': 'NutriFridge AI took longer than expected to respond. Please tap retry.',
          'error': 'TimeoutException: $e',
          'requiresConfirmation': false,
        };
      } catch (e) {
        stopwatch.stop();
        final isAuthErr = isAuthenticationFailure(e);
        if (isAuthErr && attempt == 0) {
          debugPrint(
            '[SupabaseAiFunctionClient] Auth-related network exception on attempt 0. Retrying once with forced refresh...',
          );
          continue;
        }

        final msg = _mapNetworkExceptionToMessage(e, isAfterRetry: isRetry);
        return {
          'ok': false,
          'success': false,
          'action': 'error',
          'assistantMessage': msg,
          'error': e.toString(),
          'requiresConfirmation': false,
        };
      }
    }

    // Fallback if loop exits without returning
    return {
      'ok': false,
      'success': false,
      'action': 'error',
      'assistantMessage': 'NutriFridge could not verify your session. Please sign in again.',
      'error': 'Exhausted authentication retries',
      'requiresConfirmation': false,
    };
  }

  static String _mapFunctionExceptionToMessage(FunctionException e, {required bool isAfterRetry}) {
    Map<String, dynamic>? detailsMap;
    if (e.details is Map) {
      detailsMap = Map<String, dynamic>.from(e.details as Map);
    } else if (e.details is String) {
      final rawDetails = (e.details as String).trim();
      if ((rawDetails.startsWith('{') && rawDetails.endsWith('}')) ||
          (rawDetails.startsWith('[') && rawDetails.endsWith(']'))) {
        try {
          final decoded = jsonDecode(rawDetails);
          if (decoded is Map) {
            detailsMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }

    String? backendMessage;
    dynamic errorCode;
    if (detailsMap != null) {
      if (detailsMap['error'] is Map) {
        errorCode = detailsMap['error']['code'];
        if (detailsMap['error']['message'] is String) {
          backendMessage = detailsMap['error']['message'] as String;
        }
      } else if (detailsMap['error'] is String) {
        errorCode = detailsMap['error'];
      }
      if (detailsMap['code'] is String && errorCode == null) {
        errorCode = detailsMap['code'];
      }
      if (detailsMap['assistantMessage'] is String &&
          (detailsMap['assistantMessage'] as String).trim().isNotEmpty) {
        backendMessage = (detailsMap['assistantMessage'] as String).trim();
      }
    }

    final detailsString = (e.details?.toString() ?? e.reasonPhrase ?? '').trim();
    final detailsLower = detailsString.toLowerCase();

    if (errorCode == null) {
      if (detailsLower.contains('gemini_rate_limit_exceeded') || detailsLower.contains('rate limit') || e.status == 429) {
        errorCode = 'GEMINI_RATE_LIMIT_EXCEEDED';
      } else if (detailsLower.contains('gemini_request_timeout') || detailsLower.contains('timeout') || e.status == 504) {
        errorCode = 'GEMINI_REQUEST_TIMEOUT';
      } else if (detailsLower.contains('invalid_uuid_syntax') || detailsLower.contains('invalid uuid') || detailsLower.contains('22p02')) {
        errorCode = 'INVALID_UUID_SYNTAX';
      } else if (detailsLower.contains('item_not_found') || detailsLower.contains('unauthorized item')) {
        errorCode = 'ITEM_NOT_FOUND_OR_UNAUTHORIZED';
      } else if (detailsLower.contains('user_authentication_failed') ||
          detailsLower.contains('unauthorized_legacy_jwt') ||
          detailsLower.contains('missing_authorization') ||
          detailsLower.contains('jwt') ||
          detailsLower.contains('expired') ||
          e.status == 401) {
        errorCode = 'USER_AUTHENTICATION_FAILED';
      } else if (detailsLower.contains('database_query_error') || detailsLower.contains('inventory_fetch_failed')) {
        errorCode = 'DATABASE_QUERY_ERROR';
      } else if (detailsLower.contains('empty_selection')) {
        errorCode = 'EMPTY_SELECTION';
      } else if (detailsLower.contains('invalid_ai_response')) {
        errorCode = 'INVALID_AI_RESPONSE';
      }
    }

    if (e.status == 401 ||
        errorCode == 'MISSING_AUTHORIZATION' ||
        errorCode == 'USER_AUTHENTICATION_FAILED' ||
        errorCode == 'UNAUTHORIZED_LEGACY_JWT' ||
        errorCode == 'INVALID_AUTHORIZATION_FORMAT') {
      return isAfterRetry
          ? 'NutriFridge could not verify your session. Please sign in again.'
          : 'Your session has expired. Please sign in again to continue.';
    } else if (errorCode == 'EMPTY_SELECTION') {
      return 'Please select at least one ingredient from your fridge.';
    } else if (errorCode == 'INVALID_UUID_SYNTAX') {
      return 'One or more selected ingredient IDs are invalid. Please refresh your inventory.';
    } else if (errorCode == 'ITEM_NOT_FOUND_OR_UNAUTHORIZED') {
      return 'One or more selected items could not be found in your inventory. Please refresh and try again.';
    } else if (errorCode == 'DATABASE_QUERY_ERROR' || errorCode == 'INVENTORY_FETCH_FAILED') {
      return 'Unable to verify selected ingredients from database. Please tap retry.';
    } else if (e.status == 429 || errorCode == 'GEMINI_RATE_LIMIT_EXCEEDED') {
      return 'Google Gemini rate limit exceeded. Please wait a moment and tap retry.';
    } else if (e.status == 504 || errorCode == 'GEMINI_REQUEST_TIMEOUT') {
      return 'NutriFridge AI took longer than expected to respond. Please tap retry.';
    } else if (errorCode == 'GEMINI_INVALID_REQUEST') {
      return 'Google Gemini rejected the request format. Please shorten or simplify your input.';
    } else if (errorCode == 'GEMINI_AUTH_FAILED') {
      return 'Google Gemini authentication failed. Please verify API key configuration.';
    } else if (errorCode == 'INVALID_AI_RESPONSE') {
      return 'Received an invalid response format from NutriFridge AI. Please tap retry.';
    } else if (errorCode == 'N8N_NOT_CONFIGURED') {
      return 'NutriFridge AI service is currently not configured.';
    } else if (e.status == 503 ||
        e.status == 502 ||
        errorCode == 'CONNECTION_FAILED' ||
        (errorCode is String && errorCode.startsWith('N8N_UPSTREAM_'))) {
      return 'NutriFridge AI is temporarily experiencing high load. Please tap retry.';
    } else if (backendMessage != null &&
        backendMessage.isNotEmpty &&
        !backendMessage.toLowerCase().contains('internal server error')) {
      return backendMessage;
    } else if (e.status >= 500) {
      return 'NutriFridge AI is temporarily unavailable. Please tap retry.';
    } else if (e.status == 400) {
      return 'Request could not be processed. Please check your selected ingredients.';
    }
    return 'Unable to reach NutriFridge AI. Please tap retry in a moment.';
  }

  static String _mapNetworkExceptionToMessage(dynamic e, {required bool isAfterRetry}) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('401') || errStr.contains('auth') || errStr.contains('jwt') || errStr.contains('unauthorized')) {
      return isAfterRetry
          ? 'NutriFridge could not verify your session. Please sign in again.'
          : 'Your session has expired. Please sign in again to continue.';
    } else if (errStr.contains('socket') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network') ||
        errStr.contains('connection refused') ||
        errStr.contains('clientexception')) {
      return 'Unable to reach NutriFridge AI. Please check your internet connection and tap retry.';
    } else if (errStr.contains('timeout')) {
      return 'NutriFridge AI took longer than expected to respond. Please tap retry.';
    } else if (errStr.contains('429') || errStr.contains('rate limit')) {
      return 'Google Gemini rate limit exceeded. Please wait a moment and tap retry.';
    } else if (errStr.contains('format') || errStr.contains('parse') || errStr.contains('json')) {
      return 'Received an invalid response format from NutriFridge AI. Please tap retry.';
    } else if (errStr.contains('invalid uuid') || errStr.contains('uuid')) {
      return 'One or more selected ingredient IDs are invalid. Please refresh your inventory.';
    } else if (errStr.contains('item not found') || errStr.contains('not found')) {
      return 'One or more selected items could not be found in your inventory. Please refresh and try again.';
    }
    return 'Unable to reach NutriFridge AI. Please tap retry.';
  }

  /// Normalizes incoming edge function / n8n JSON responses into standard contract maps.
  static Map<String, dynamic> normalizeResponse(dynamic raw) {
    if (raw == null) {
      return {
        'ok': false,
        'success': false,
        'action': 'error',
        'assistantMessage': 'Received an empty response from NutriFridge AI. Please tap retry.',
        'error': 'Response was null',
        'requiresConfirmation': false,
      };
    }

    Map<String, dynamic> map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        } else {
          return {
            'ok': true,
            'success': true,
            'action': 'assistant_reply',
            'assistantMessage': raw,
            'requiresConfirmation': false,
          };
        }
      } catch (_) {
        return {
          'ok': true,
          'success': true,
          'action': 'assistant_reply',
          'assistantMessage': raw,
          'requiresConfirmation': false,
        };
      }
    } else {
      return {
        'ok': false,
        'success': false,
        'action': 'error',
        'assistantMessage': 'Unexpected response type from NutriFridge AI.',
        'error': 'Unsupported response type: ${raw.runtimeType}',
        'requiresConfirmation': false,
      };
    }

    if (map['output'] is Map) {
      map = Map<String, dynamic>.from(map['output'] as Map);
    } else if (map['data'] is Map && map['data']['output'] is Map) {
      map = Map<String, dynamic>.from(map['data']['output'] as Map);
    }

    final bool ok = map['ok'] == true || (map['success'] == true && map['action'] != 'error');
    final String action = map['action']?.toString() ?? (ok ? 'assistant_reply' : 'error');
    final String message = map['assistantMessage']?.toString() ??
        map['message']?.toString() ??
        (ok ? 'Action completed.' : 'An error occurred.');

    return {
      ...map,
      'ok': ok,
      'success': ok,
      'action': action,
      'assistantMessage': message,
      'requiresConfirmation': map['requiresConfirmation'] == true,
    };
  }
}
