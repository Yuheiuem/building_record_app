import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/health_check_response.dart';

abstract interface class AppsScriptApiService {
  Future<HealthCheckResponse> healthCheck({
    required String requestId,
    required String clientVersion,
  });

  void close();
}

class HttpAppsScriptApiService implements AppsScriptApiService {
  HttpAppsScriptApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 20);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<HealthCheckResponse> healthCheck({
    required String requestId,
    required String clientVersion,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'healthCheck',
      'requestId': requestId,
      'idToken': null,
      'clientVersion': clientVersion,
      'payload': <String, Object?>{},
    });

    try {
      final http.Response response = await _client
          .post(
            _endpoint,
            headers: const <String, String>{
              'Content-Type': 'text/plain;charset=utf-8',
            },
            body: requestBody,
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppsScriptApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppsScriptApiException('Apps Scriptの応答がJSONオブジェクトではありません。');
      }

      final HealthCheckResponse result = HealthCheckResponse.fromJson(decoded);

      if (!result.ok) {
        throw AppsScriptApiException(
          result.message ?? 'Apps ScriptのhealthCheckが失敗しました。',
          errorCode: result.errorCode,
        );
      }

      return result;
    } on TimeoutException {
      throw const AppsScriptApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException {
      throw const AppsScriptApiException('Apps Scriptの応答をJSONとして読み取れませんでした。');
    } on http.ClientException {
      throw const AppsScriptApiException(
        'Apps Scriptへ接続できませんでした。ブラウザまたは社内ネットワークの制限を確認してください。',
      );
    }
  }

  @override
  void close() {
    _client.close();
  }
}

class AppsScriptApiException implements Exception {
  const AppsScriptApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}
