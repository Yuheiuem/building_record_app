import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/building_detail_data.dart';

abstract interface class BuildingDetailApiService {
  Future<BuildingDetailData> getBuildingDetail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  });

  void close();
}

class HttpBuildingDetailApiService implements BuildingDetailApiService {
  HttpBuildingDetailApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<BuildingDetailData> getBuildingDetail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getBuildingDetail',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId},
    );
    try {
      return BuildingDetailData.fromJson(response);
    } on FormatException catch (error) {
      throw BuildingDetailApiException(
        '建物詳細の応答を読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getPhotoData',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'photoId': photoId},
    );
    try {
      return BuildingPhotoData.fromJson(response);
    } on FormatException catch (error) {
      throw BuildingDetailApiException(
        '写真データの応答を読み取れませんでした。${error.message}',
      );
    }
  }

  Future<Map<String, dynamic>> _post({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
    required Map<String, Object?> payload,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': action,
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': payload,
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
        throw BuildingDetailApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BuildingDetailApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }

      if (decoded['ok'] != true) {
        throw BuildingDetailApiException(
          _optionalString(decoded['message']) ?? 'データを取得できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }

      return decoded;
    } on TimeoutException {
      throw const BuildingDetailApiException(
        'Apps Scriptから時間内に応答がありませんでした。',
      );
    } on FormatException catch (error) {
      throw BuildingDetailApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const BuildingDetailApiException(
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

class BuildingDetailApiException implements Exception {
  const BuildingDetailApiException(
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
