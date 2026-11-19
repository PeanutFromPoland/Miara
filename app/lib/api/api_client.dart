import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Adres API jest podawany podczas uruchomienia, np. przez
/// --dart-define=API_BASE_URL=https://api.example.org.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

class ApiSession {
  const ApiSession({
    required this.sessionId,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    this.refreshExpiresAt,
  });

  final String sessionId;
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime? refreshExpiresAt;

  factory ApiSession.fromJson(Map<String, dynamic> json) => ApiSession(
    sessionId: json['session_id'] as String? ?? '',
    accessToken: json['access_token'] as String,
    accessExpiresAt: DateTime.parse(json['access_expires_at'] as String),
    refreshToken: json['refresh_token'] as String,
    refreshExpiresAt: json['refresh_expires_at'] == null
        ? null
        : DateTime.parse(json['refresh_expires_at'] as String),
  );

  factory ApiSession.fromRefreshJson(
    Map<String, dynamic> json,
    ApiSession previous,
  ) => ApiSession(
    sessionId: json['session_id'] as String? ?? previous.sessionId,
    accessToken: json['access_token'] as String,
    accessExpiresAt: DateTime.parse(json['access_expires_at'] as String),
    refreshToken: json['refresh_token'] as String? ?? previous.refreshToken,
    refreshExpiresAt: json['refresh_expires_at'] == null
        ? previous.refreshExpiresAt
        : DateTime.parse(json['refresh_expires_at'] as String),
  );
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
    this.requestId,
  });

  final int statusCode;
  final String code;
  final String message;
  final Object? details;
  final String? requestId;

  factory ApiException.fromResponse(int status, Object? value) {
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      return ApiException(
        statusCode: status,
        code: json['code'] as String? ?? 'HTTP_$status',
        message: json['message'] as String? ?? 'Żądanie nie powiodło się.',
        details: json['details'],
        requestId: json['request_id'] as String?,
      );
    }
    return ApiException(
      statusCode: status,
      code: 'HTTP_$status',
      message: 'Serwer zwrócił odpowiedź, której aplikacja nie rozumie.',
    );
  }

  @override
  String toString() => '$code: $message';
}

class RecipeSearchResult {
  const RecipeSearchResult({
    required this.recipeVersionId,
    required this.title,
    required this.raw,
    this.kcal,
    this.proteinG,
    this.carbohydrateG,
    this.fatG,
    this.completeness,
    this.sourceUrl,
    this.matchStatus,
  });

  final String recipeVersionId;
  final String title;
  final Map<String, dynamic> raw;
  final num? kcal;
  final num? proteinG;
  final num? carbohydrateG;
  final num? fatG;
  final String? completeness;
  final String? sourceUrl;
  final String? matchStatus;

  factory RecipeSearchResult.fromJson(Map<String, dynamic> json) {
    final estimate = json['estimate_per_serving'] is Map
        ? Map<String, dynamic>.from(json['estimate_per_serving'] as Map)
        : const <String, dynamic>{};
    final source = json['source'] is Map
        ? Map<String, dynamic>.from(json['source'] as Map)
        : const <String, dynamic>{};
    final match = json['match'] is Map
        ? Map<String, dynamic>.from(json['match'] as Map)
        : const <String, dynamic>{};
    return RecipeSearchResult(
      recipeVersionId: json['recipe_version_id'] as String,
      title: json['title'] as String,
      raw: Map<String, dynamic>.from(json),
      kcal: estimate['kcal'] as num?,
      proteinG: estimate['protein_g'] as num?,
      carbohydrateG: estimate['carbohydrate_g'] as num?,
      fatG: estimate['fat_g'] as num?,
      completeness: estimate['completeness'] as String?,
      sourceUrl: source['url'] as String?,
      matchStatus: match['status'] as String?,
    );
  }
}

/// Klient kontraktu Miara v1. Token jest trzymany w pamięci procesu.
/// Przed wdrożeniem trzeba podłączyć bezpieczny magazyn platformy dla sesji.
class ApiClient {
  ApiClient({String? baseUrl, HttpClient? httpClient, this.onSessionChanged})
    : _baseUri = _parseBaseUrl(baseUrl ?? apiBaseUrl),
      _http = httpClient ?? HttpClient() {
    _http.connectionTimeout = const Duration(seconds: 5);
  }

  final Uri _baseUri;
  final HttpClient _http;
  final void Function(ApiSession? session)? onSessionChanged;
  ApiSession? _session;
  Future<void>? _refreshInFlight;

  ApiSession? get session => _session;
  bool get isConfigured => _baseUri.host.isNotEmpty;

  static Uri _parseBaseUrl(String value) {
    if (value.trim().isEmpty) return Uri();
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'https' && parsed.scheme != 'http')) {
      throw const FormatException(
        'Skonfiguruj API_BASE_URL jako adres http(s), np. https://api.example.org.',
      );
    }
    return parsed.replace(path: parsed.path.replaceFirst(RegExp(r'/$'), ''));
  }

  void setSession(ApiSession? session) {
    _session = session;
    onSessionChanged?.call(session);
  }

  Future<ApiSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _sendJson(
      'POST',
      '/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
      retryable: false,
    );
    final session = ApiSession.fromJson(json);
    setSession(session);
    return session;
  }

  Future<ApiSession> register({
    required String email,
    required String password,
  }) async {
    final json = await _sendJson(
      'POST',
      '/v1/auth/register',
      body: {'email': email, 'password': password},
      authenticated: false,
      retryable: false,
    );
    final session = ApiSession.fromJson(json);
    setSession(session);
    return session;
  }

  Future<void> logout() async {
    await _sendJson(
      'POST',
      '/v1/auth/logout',
      authenticated: true,
      retryable: true,
      allowEmpty: true,
      operationKey: _logoutOperationId ??= newOperationId(),
    );
    _logoutOperationId = null;
    setSession(null);
  }

  String? _logoutOperationId;

  Future<Map<String, dynamic>> getMe() => _sendJson('GET', '/v1/me');

  Future<Map<String, dynamic>> getProfile() => _sendJson('GET', '/v1/profile');

  Future<Map<String, dynamic>> createProfile({
    required Map<String, dynamic> profile,
    required String operationId,
  }) => _sendJson(
    'POST',
    '/v1/profile',
    body: profile,
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> updateProfile({
    required int version,
    required Map<String, dynamic> patch,
    required String operationId,
  }) => _sendJson(
    'PATCH',
    '/v1/profile',
    body: {...patch, 'version': version},
    operationKey: operationId,
  );

  Future<void> deleteProfile({
    required int version,
    required String operationId,
  }) => _sendJson(
    'DELETE',
    '/v1/profile',
    body: {'version': version},
    allowEmpty: true,
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> createRecipeSearch({
    required String query,
    required String operationId,
    int? maxTimeMinutes,
    int? maxIngredients,
    int? minKcal,
    int? maxKcal,
    num? minProteinG,
    bool? vegetarianOnly,
  }) => _sendJson(
    'POST',
    '/v1/recipe-searches',
    body: {
      'query': query,
      'max_time_minutes': ?maxTimeMinutes,
      'max_ingredients': ?maxIngredients,
      'min_kcal_per_serving': ?minKcal,
      'max_kcal_per_serving': ?maxKcal,
      'min_protein_g_per_serving': ?minProteinG,
      'vegetarian_only': ?vegetarianOnly,
    },
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> getRecipeSearch(
    String searchId, {
    String? cursor,
  }) => _sendJson(
    'GET',
    '/v1/recipe-searches/${Uri.encodeComponent(searchId)}',
    query: {'cursor': ?cursor},
  );

  Future<Map<String, dynamic>> cancelRecipeSearch(
    String searchId, {
    required String operationId,
  }) => _sendJson(
    'POST',
    '/v1/recipe-searches/${Uri.encodeComponent(searchId)}/cancel',
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> getRecipe(String versionId) =>
      _sendJson('GET', '/v1/recipes/${Uri.encodeComponent(versionId)}');

  Future<Map<String, dynamic>> getRecipeEstimate(String versionId) => _sendJson(
    'GET',
    '/v1/recipes/${Uri.encodeComponent(versionId)}/estimate',
  );

  Future<Map<String, dynamic>> getPlan(String date) =>
      _sendJson('GET', '/v1/plan', query: {'date': date});

  Future<Map<String, dynamic>> createPlanEntry({
    required String id,
    required String date,
    required String recipeVersionId,
    required double servings,
    required String operationId,
  }) => _sendJson(
    'POST',
    '/v1/plan/entries',
    body: {
      'id': id,
      'local_date': date,
      'recipe_version_id': recipeVersionId,
      'servings': servings,
    },
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> updatePlanEntry({
    required String id,
    required int version,
    required String operationId,
    Map<String, dynamic> patch = const {},
  }) => _sendJson(
    'PATCH',
    '/v1/plan/entries/${Uri.encodeComponent(id)}',
    body: {...patch, 'version': version},
    operationKey: operationId,
  );

  Future<void> deletePlanEntry({
    required String id,
    required int version,
    required String operationId,
  }) => _sendJson(
    'DELETE',
    '/v1/plan/entries/${Uri.encodeComponent(id)}',
    body: {'version': version},
    allowEmpty: true,
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> getDiary(String date) =>
      _sendJson('GET', '/v1/diary', query: {'date': date});

  Future<Map<String, dynamic>> createDiaryEntry({
    required String id,
    required String date,
    required String origin,
    required Map<String, dynamic> snapshot,
    required String operationId,
    String? planEntryId,
  }) => _sendJson(
    'POST',
    '/v1/diary/entries',
    body: {
      'id': id,
      'local_date': date,
      'origin': origin,
      'plan_entry_id': planEntryId,
      ...snapshot,
    },
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> updateDiaryEntry({
    required String id,
    required int version,
    required Map<String, dynamic> patch,
    required String operationId,
  }) => _sendJson(
    'PATCH',
    '/v1/diary/entries/${Uri.encodeComponent(id)}',
    body: {...patch, 'version': version},
    operationKey: operationId,
  );

  Future<void> deleteDiaryEntry({
    required String id,
    required int version,
    required String operationId,
  }) => _sendJson(
    'DELETE',
    '/v1/diary/entries/${Uri.encodeComponent(id)}',
    body: {'version': version},
    allowEmpty: true,
    operationKey: operationId,
  );

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryable = true,
    bool allowEmpty = false,
    bool mayRefresh = true,
    String? operationKey,
  }) async {
    if (!isConfigured) {
      throw const ApiException(
        statusCode: 0,
        code: 'API_NOT_CONFIGURED',
        message: 'Skonfiguruj adres serwera przez parametr API_BASE_URL.',
      );
    }
    final requestOperationKey = operationKey ?? newOperationId();
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    final bodyBytes = body == null ? null : utf8.encode(jsonEncode(body));
    final canRetry =
        retryable && (method == 'GET' || requestOperationKey.isNotEmpty);
    var attempt = 0;

    while (true) {
      attempt++;
      try {
        final request = await _http
            .openUrl(method, uri)
            .timeout(const Duration(seconds: 5));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set('X-Client-Version', '1');
        if (bodyBytes != null) {
          request.headers.contentType = ContentType.json;
          request.add(bodyBytes);
        }
        if (method != 'GET') {
          request.headers.set('Idempotency-Key', requestOperationKey);
        }
        if (authenticated && _session != null) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer ${_session!.accessToken}',
          );
        }

        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        final responseText = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 20));
        final decoded = responseText.isEmpty
            ? null
            : _tryDecodeJson(responseText);

        if (response.statusCode == 401 &&
            authenticated &&
            mayRefresh &&
            _session != null &&
            !path.endsWith('/auth/refresh')) {
          await _refreshSession();
          return await _sendJson(
            method,
            path,
            query: query,
            body: body,
            authenticated: authenticated,
            retryable: retryable,
            allowEmpty: allowEmpty,
            mayRefresh: false,
            operationKey: requestOperationKey,
          );
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (allowEmpty && (response.statusCode == 204 || decoded == null)) {
            return <String, dynamic>{};
          }
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
          throw const FormatException('Odpowiedź API nie jest obiektem JSON.');
        }

        final error = ApiException.fromResponse(response.statusCode, decoded);
        final retryDelay = _retryDelay(response.headers, attempt);
        final canRetryResponse =
            canRetry &&
            attempt < 3 &&
            (response.statusCode == 429 ||
                response.statusCode == 503 ||
                response.statusCode >= 500);
        if (canRetryResponse) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        throw error;
      } on ApiException {
        rethrow;
      } on SocketException catch (error) {
        if (canRetry && attempt < 3) {
          await Future<void>.delayed(_retryDelay(null, attempt));
          continue;
        }
        throw ApiException(
          statusCode: 0,
          code: 'NETWORK_UNAVAILABLE',
          message: 'Nie można połączyć się z serwerem. Sprawdź połączenie i ponów próbę.',
          details: error.message,
        );
      } on TimeoutException {
        if (canRetry && attempt < 3) {
          await Future<void>.delayed(_retryDelay(null, attempt));
          continue;
        }
        throw const ApiException(
          statusCode: 0,
          code: 'REQUEST_TIMEOUT',
          message: 'Serwer nie odpowiedział na czas. Możesz ponowić żądanie.',
        );
      } on HandshakeException {
        throw const ApiException(
          statusCode: 0,
          code: 'TLS_ERROR',
          message: 'Nie udało się bezpiecznie połączyć z serwerem.',
        );
      } on FormatException {
        throw const ApiException(
          statusCode: 0,
          code: 'INVALID_RESPONSE',
          message: 'Serwer zwrócił nieprawidłową odpowiedź.',
        );
      } on HttpException {
        if (canRetry && attempt < 3) {
          await Future<void>.delayed(_retryDelay(null, attempt));
          continue;
        }
        throw const ApiException(
          statusCode: 0,
          code: 'HTTP_TRANSPORT_ERROR',
          message: 'Nie udało się odczytać odpowiedzi serwera.',
        );
      }
    }
  }

  Future<void> _refreshSession() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<void> _performRefresh() async {
    final current = _session;
    if (current == null) {
      throw const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'Zaloguj się ponownie, aby kontynuować.',
      );
    }
    try {
      final json = await _sendJson(
        'POST',
        '/v1/auth/refresh',
        body: {'refresh_token': current.refreshToken},
        authenticated: false,
        retryable: true,
        mayRefresh: false,
      );
      setSession(ApiSession.fromRefreshJson(json, current));
    } on ApiException catch (error) {
      if (error.code == 'UNAUTHENTICATED') setSession(null);
      rethrow;
    }
  }

  Duration _retryDelay(HttpHeaders? headers, int attempt) {
    final retryAfter = headers?.value(HttpHeaders.retryAfterHeader);
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) return Duration(seconds: max(0, seconds));
      try {
        final date = HttpDate.parse(retryAfter);
        final remaining = date.difference(DateTime.now().toUtc());
        if (!remaining.isNegative) return remaining;
      } catch (_) {
        // Niepoprawny Retry-After: użyj odstępu z polityki ponowień klienta.
      }
    }
    return attempt == 1
        ? const Duration(seconds: 2)
        : const Duration(seconds: 5);
  }

  Object? _tryDecodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  void close() => _http.close(force: true);
}

String newOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
