import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

abstract interface class VisitInformationApiService {
  Future<void> updateVisitInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double? latitude,
    required double? longitude,
    required double? accuracyM,
    required String locationSource,
  });

  void close();
}

class HttpVisitInformationApiService implements VisitInformationApiService {
  HttpVisitInformationApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<void> updateVisitInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double? latitude,
    required double? longitude,
    required double? accuracyM,
    required String locationSource,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'updateVisitInformation',
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': <String, Object?>{
        'buildingId': buildingId,
        'visitId': visitId,
        'visitedAt': visitedAt.toIso8601String(),
        'triggerTagIds': triggerTagIds,
        'impression': impression,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyM': accuracyM,
        'locationSource': locationSource,
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
        throw VisitInformationApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const VisitInformationApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw VisitInformationApiException(
          _optionalString(decoded['message']) ?? '訪問記録を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
    } on TimeoutException {
      throw const VisitInformationApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw VisitInformationApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const VisitInformationApiException(
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

class VisitInformationApiException implements Exception {
  const VisitInformationApiException(
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
