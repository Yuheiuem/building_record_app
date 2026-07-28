import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/bootstrap_data.dart';

abstract interface class BootstrapApiService {
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  });

  void close();
}

class HttpBootstrapApiService implements BootstrapApiService {
  HttpBootstrapApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'getBootstrapData',
      'requestId': requestId,
      'idToken': idToken,
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
        throw BootstrapApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BootstrapApiException('Apps Scriptの応答がJSONオブジェクトではありません。');
      }

      if (decoded['ok'] != true) {
        throw BootstrapApiException(
          _optionalString(decoded['message']) ?? 'データを取得できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }

      return BootstrapData.fromJson(decoded);
    } on TimeoutException {
      throw const BootstrapApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw BootstrapApiException('Apps Scriptの応答を読み取れませんでした。${error.message}');
    } on http.ClientException {
      throw const BootstrapApiException(
        'Apps Scriptへ接続できませんでした。ブラウザまたは社内ネットワークの制限を確認してください。',
      );
    }
  }

  String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String result = value.trim();
    return result.isEmpty ? null : result;
  }

  @override
  void close() {
    _client.close();
  }
}

class BootstrapApiException implements Exception {
  const BootstrapApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}
