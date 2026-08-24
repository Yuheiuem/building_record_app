import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/building_detail_data.dart';

abstract interface class PhotoLifecycleApiService {
  Future<List<BuildingPhoto>> getHiddenBuildingPhotos({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  });

  Future<BuildingPhotoData> getHiddenPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  });

  Future<void> hidePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  });

  Future<void> restorePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  });

  Future<void> deletePhotoPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  });

  void close();
}

class HttpPhotoLifecycleApiService implements PhotoLifecycleApiService {
  HttpPhotoLifecycleApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<List<BuildingPhoto>> getHiddenBuildingPhotos({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getHiddenBuildingPhotos',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId},
    );

    final Object? rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const PhotoLifecycleApiException('非表示写真の応答にdataがありません。');
    }
    final Object? rawPhotos = rawData['photos'];
    if (rawPhotos is! List<dynamic>) {
      throw const PhotoLifecycleApiException('非表示写真の応答を読み取れませんでした。');
    }

    try {
      return List<BuildingPhoto>.unmodifiable(
        rawPhotos.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('写真情報がJSONオブジェクトではありません。');
          }
          return BuildingPhoto.fromJson(item);
        }),
      );
    } on FormatException catch (error) {
      throw PhotoLifecycleApiException(
        '非表示写真の応答を読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<BuildingPhotoData> getHiddenPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getHiddenPhotoThumbnailData',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'photoId': photoId},
    );
    try {
      return BuildingPhotoData.fromJson(response);
    } on FormatException catch (error) {
      throw PhotoLifecycleApiException(
        '非表示写真のプレビューを読み取れませんでした。${error.message}',
      );
    }
  }

  @override
  Future<void> hidePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) {
    return _mutatePhoto(
      action: 'hidePhoto',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      photoId: photoId,
    );
  }

  @override
  Future<void> restorePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) {
    return _mutatePhoto(
      action: 'restorePhoto',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      photoId: photoId,
    );
  }

  @override
  Future<void> deletePhotoPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) {
    return _mutatePhoto(
      action: 'deletePhotoPermanently',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      buildingId: buildingId,
      photoId: photoId,
    );
  }

  Future<void> _mutatePhoto({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) async {
    await _post(
      action: action,
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{
        'buildingId': buildingId,
        'photoId': photoId,
      },
    );
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
        throw PhotoLifecycleApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const PhotoLifecycleApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw PhotoLifecycleApiException(
          _optionalString(decoded['message']) ?? '写真を更新できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const PhotoLifecycleApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw PhotoLifecycleApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const PhotoLifecycleApiException(
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

class PhotoLifecycleApiException implements Exception {
  const PhotoLifecycleApiException(
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
