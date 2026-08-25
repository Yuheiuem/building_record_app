import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/building.dart';

class BuildingLifecycleSummary {
  const BuildingLifecycleSummary({
    required this.building,
    required this.visitCount,
    required this.photoCount,
    required this.photoBytes,
  });

  factory BuildingLifecycleSummary.fromJson(Map<String, dynamic> json) {
    final Object? rawBuilding = json['building'];
    if (rawBuilding is! Map<String, dynamic>) {
      throw const FormatException('buildingがJSONオブジェクトではありません。');
    }

    return BuildingLifecycleSummary(
      building: Building.fromJson(rawBuilding),
      visitCount: _requiredInt(json['visitCount'], 'visitCount'),
      photoCount: _requiredInt(json['photoCount'], 'photoCount'),
      photoBytes: _requiredInt(json['photoBytes'], 'photoBytes'),
    );
  }

  final Building building;
  final int visitCount;
  final int photoCount;
  final int photoBytes;
}

abstract interface class BuildingLifecycleApiService {
  Future<List<BuildingLifecycleSummary>> getHiddenBuildings({
    required String requestId,
    required String clientVersion,
    required String idToken,
  });

  Future<BuildingLifecycleSummary> getBuildingDeletionPreview({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<void> hideBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<void> restoreBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<void> deleteBuildingPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  void close();
}

class HttpBuildingLifecycleApiService implements BuildingLifecycleApiService {
  HttpBuildingLifecycleApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<List<BuildingLifecycleSummary>> getHiddenBuildings({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getHiddenBuildings',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: const <String, Object?>{},
    );

    final Map<String, dynamic> data = _requiredData(response);
    final Object? rawBuildings = data['buildings'];
    if (rawBuildings is! List<dynamic>) {
      throw const BuildingLifecycleApiException('非表示建物の応答を読み取れませんでした。');
    }

    try {
      return List<BuildingLifecycleSummary>.unmodifiable(
        rawBuildings.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('建物情報がJSONオブジェクトではありません。');
          }
          return BuildingLifecycleSummary.fromJson(item);
        }),
      );
    } on FormatException catch (error) {
      throw BuildingLifecycleApiException(
        '非表示建物の応答を読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<BuildingLifecycleSummary> getBuildingDeletionPreview({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getBuildingDeletionPreview',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId},
    );

    final Map<String, dynamic> data = _requiredData(response);
    final Object? rawSummary = data['summary'];
    if (rawSummary is! Map<String, dynamic>) {
      throw const BuildingLifecycleApiException('建物削除確認の応答を読み取れませんでした。');
    }
    try {
      return BuildingLifecycleSummary.fromJson(rawSummary);
    } on FormatException catch (error) {
      throw BuildingLifecycleApiException(
        '建物削除確認の応答を読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<void> hideBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) {
    return _mutateBuilding(
      action: 'hideBuilding',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
    );
  }

  @override
  Future<void> restoreBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) {
    return _mutateBuilding(
      action: 'restoreBuilding',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
    );
  }

  @override
  Future<void> deleteBuildingPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) {
    return _mutateBuilding(
      action: 'deleteBuildingPermanently',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
    );
  }

  Future<void> _mutateBuilding({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    await _post(
      action: action,
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId},
    );
  }

  Map<String, dynamic> _requiredData(Map<String, dynamic> response) {
    final Object? rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const BuildingLifecycleApiException('Apps Scriptの応答にdataがありません。');
    }
    return rawData;
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
        throw BuildingLifecycleApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BuildingLifecycleApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw BuildingLifecycleApiException(
          _optionalString(decoded['message']) ?? '建物を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const BuildingLifecycleApiException(
        'Apps Scriptから時間内に応答がありませんでした。',
      );
    } on FormatException catch (error) {
      throw BuildingLifecycleApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const BuildingLifecycleApiException(
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

class BuildingLifecycleApiException implements Exception {
  const BuildingLifecycleApiException(
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

int _requiredInt(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$fieldNameが数値ではありません。');
}
