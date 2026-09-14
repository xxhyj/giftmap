import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 서버를 부르다 생긴 문제.
///
/// 화면은 이 하나만 알면 된다. 연결 실패·시간 초과·잘못된 JSON·오류 응답을
/// 모두 여기로 모아, 부르는 쪽이 곳곳에서 다른 예외를 받지 않게 한다.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;

  /// 서버가 준 상태 코드. 연결 자체가 안 됐으면 null.
  final int? statusCode;

  /// 서버가 준 오류 코드(`not_configured`, `rate_limited` 같은 것).
  final String? code;

  @override
  String toString() =>
      'ApiException($message${statusCode == null ? '' : ', status=$statusCode'})';
}

/// JSON 을 주고받는 최소한의 계약.
///
/// 패키지를 늘리지 않으려고 인터페이스만 두고, 실제 통신은 [IoJsonHttpClient]가
/// `dart:io`로 한다. 테스트는 이 계약을 대신 구현해 네트워크 없이 확인한다.
abstract interface class JsonHttpClient {
  /// 성공하면 JSON 을 해석한 결과(Map 또는 List)를 돌려준다.
  Future<Object?> getJson(Uri url);

  /// [body]를 JSON 으로 보내고 JSON 을 받는다.
  Future<Object?> postJson(Uri url, Map<String, Object?> body);

  /// 더 쓰지 않을 때 연결을 정리한다.
  void close();
}

/// `dart:io`의 HttpClient 로 통신하는 구현체.
final class IoJsonHttpClient implements JsonHttpClient {
  IoJsonHttpClient({
    Duration timeout = const Duration(seconds: 15),
    HttpClient? client,
  }) : _timeout = timeout,
       _client = client ?? (HttpClient()..connectionTimeout = timeout);

  final HttpClient _client;
  final Duration _timeout;

  @override
  Future<Object?> getJson(Uri url) => _send(url, method: 'GET');

  @override
  Future<Object?> postJson(Uri url, Map<String, Object?> body) =>
      _send(url, method: 'POST', body: body);

  Future<Object?> _send(
    Uri url, {
    required String method,
    Map<String, Object?>? body,
  }) async {
    HttpClientResponse response;
    String raw;
    try {
      final HttpClientRequest request = await _client
          .openUrl(method, url)
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      response = await request.close().timeout(_timeout);
      raw = await response.transform(utf8.decoder).join().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('서버가 제때 답하지 않았습니다.');
    } on SocketException catch (error) {
      throw ApiException('서버에 연결하지 못했습니다: ${error.osError?.message ?? ''}');
    } on HttpException catch (error) {
      throw ApiException('서버 응답을 받지 못했습니다: ${error.message}');
    }

    return decodeResponse(status: response.statusCode, body: raw);
  }

  @override
  void close() => _client.close(force: true);
}

/// 상태 코드와 본문을 함께 보고 결과를 정한다.
///
/// 통신 방법과 상관없는 판단이라 따로 두고 테스트한다.
/// - 2xx 가 아니면 서버가 준 오류 코드를 실어 [ApiException]
/// - 본문이 비었거나 JSON 이 아니면 [ApiException] (앱이 깨지지 않게)
Object? decodeResponse({required int status, required String body}) {
  Object? parsed;
  if (body.trim().isNotEmpty) {
    try {
      parsed = jsonDecode(body);
    } on FormatException {
      parsed = null;
    }
  }

  if (status < 200 || status >= 300) {
    String message = '서버가 $status 를 돌려줬습니다.';
    String? code;
    if (parsed is Map && parsed['error'] is Map) {
      final Map<Object?, Object?> error =
          parsed['error']! as Map<Object?, Object?>;
      code = error['code']?.toString();
      final String? detail = error['message']?.toString();
      if (detail != null && detail.isNotEmpty) message = detail;
    }
    throw ApiException(message, statusCode: status, code: code);
  }

  if (parsed == null) {
    throw ApiException(
      body.trim().isEmpty ? '서버가 빈 응답을 보냈습니다.' : '서버 응답을 읽지 못했습니다.',
      statusCode: status,
    );
  }
  return parsed;
}
