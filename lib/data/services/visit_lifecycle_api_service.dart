import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/building_detail_data.dart';

class VisitLifecycleSummary {
  const VisitLifecycleSummary({
    required this.visit,
    required this.photoCount,
    required this.photoBytes,
  });

  factory VisitLifecycleSummary.fromJson(Map<String, dynamic> json) {
    final Object? rawVisit = json['visit'];
    if (rawVisit is! Map<String, dynamic>) {
      throw const FormatException('visitがJSONオブジェクトではありません。');
    }

    return VisitLifecycleSummary(
      visit: BuildingVisit.fromJson(rawVisit),
      photoCount: _requiredInt(json['photoCount'], 'photoCount'),
      photoBytes: _requiredInt(json['photoBytes'], 'photoBytes'),
    );
  }

  final BuildingVisit visit;
  final int photoCount;
  final int photoBytes;
}

abstract interface class VisitLifecycleApiService {
  Future<List<VisitLifecycleSummary>> getHiddenBuildingVisits({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<void> hideVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  });

  Future<void> restoreVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  });

  Future<void> deleteVisitPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  });

  void close();
}

class HttpVisitLifecycleApiService implements VisitLifecycleApiService {
  HttpVisitLifecycleApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<List<VisitLifecycleSummary>> getHiddenBuildingVisits({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getHiddenBuildingVisits',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId},
    );

    final Map<String, dynamic> data = _requiredData(response);
    final Object? rawVisits = data['visits'];
    if (rawVisits is! List<dynamic>) {
      throw const VisitLifecycleApiException('非表示の訪問記録の応答を読み取れませんでした。');
    }

    try {
      return List<VisitLifecycleSummary>.unmodifiable(
        rawVisits.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('訪問記録がJSONオブジェクトではありません。');
          }
          return VisitLifecycleSummary.fromJson(item);
        }),
      );
    } on FormatException catch (error) {
      throw VisitLifecycleApiException(
        '非表示の訪問記録の応答を読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<void> hideVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    return _mutateVisit(
      action: 'hideVisit',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      visitId: visitId,
    );
  }

  @override
  Future<void> restoreVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    return _mutateVisit(
      action: 'restoreVisit',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      visitId: visitId,
    );
  }

  @override
  Future<void> deleteVisitPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    return _mutateVisit(
      action: 'deleteVisitPermanently',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      visitId: visitId,
    );
  }

  Future<void> _mutateVisit({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    await _post(
      action: action,
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId, 'visitId': visitId},
    );
  }

  Map<String, dynamic> _requiredData(Map<String, dynamic> response) {
    final Object? rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const VisitLifecycleApiException('Apps Scriptの応答にdataがありません。');
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
        throw VisitLifecycleApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const VisitLifecycleApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw VisitLifecycleApiException(
          _optionalString(decoded['message']) ?? '訪問記録を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const VisitLifecycleApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw VisitLifecycleApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const VisitLifecycleApiException(
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

class VisitLifecycleApiException implements Exception {
  const VisitLifecycleApiException(
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
