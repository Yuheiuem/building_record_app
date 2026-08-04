import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

abstract interface class BuildingInformationApiService {
  Future<void> updateBuildingInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String buildingName,
    required String? address,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
  });

  void close();
}

class HttpBuildingInformationApiService
    implements BuildingInformationApiService {
  HttpBuildingInformationApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<void> updateBuildingInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String buildingName,
    required String? address,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'updateBuildingInformation',
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': <String, Object?>{
        'buildingId': buildingId,
        'buildingName': buildingName,
        'address': address,
        'designTagIds': designTagIds,
        'salesTagIds': salesTagIds,
        'constructionTagIds': constructionTagIds,
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
        throw BuildingInformationApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BuildingInformationApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw BuildingInformationApiException(
          _optionalString(decoded['message']) ?? '建物情報を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
    } on TimeoutException {
      throw const BuildingInformationApiException(
        'Apps Scriptから時間内に応答がありませんでした。',
      );
    } on FormatException catch (error) {
      throw BuildingInformationApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const BuildingInformationApiException(
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

class BuildingInformationApiException implements Exception {
  const BuildingInformationApiException(
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
