import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

abstract interface class BuildingLocationApiService {
  Future<void> updateBuildingLocation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required double latitude,
    required double longitude,
  });

  void close();
}

class HttpBuildingLocationApiService implements BuildingLocationApiService {
  HttpBuildingLocationApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<void> updateBuildingLocation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required double latitude,
    required double longitude,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'updateBuildingLocation',
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': <String, Object?>{
        'buildingId': buildingId,
        'latitude': latitude,
        'longitude': longitude,
      },
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
        throw BuildingLocationApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BuildingLocationApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw BuildingLocationApiException(
          _optionalString(decoded['message']) ?? '代表位置を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
    } on TimeoutException {
      throw const BuildingLocationApiException(
        'Apps Scriptから時間内に応答がありませんでした。',
      );
    } on FormatException catch (error) {
      throw BuildingLocationApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const BuildingLocationApiException(
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

class BuildingLocationApiException implements Exception {
  const BuildingLocationApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}
