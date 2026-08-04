import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class BuildingCoverThumbnailData {
  const BuildingCoverThumbnailData({
    required this.photoId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.bytes,
    required this.source,
  });

  factory BuildingCoverThumbnailData.fromJson(Map<String, dynamic> json) {
    final String photoId = _requiredString(json['photoId'], 'photoId');
    final String fileName = _requiredString(json['fileName'], 'fileName');
    final String mimeType = _requiredString(json['mimeType'], 'mimeType');
    final int byteSize = _requiredInt(json['byteSize'], 'byteSize');
    final String base64Data = _requiredString(json['base64Data'], 'base64Data');
    final String source = _requiredString(json['source'], 'source');

    Uint8List bytes;
    try {
      bytes = base64Decode(base64Data);
    } on FormatException {
      throw const FormatException('base64Dataが正しいBase64ではありません。');
    }

    return BuildingCoverThumbnailData(
      photoId: photoId,
      fileName: fileName,
      mimeType: mimeType,
      byteSize: byteSize,
      bytes: bytes,
      source: source,
    );
  }

  final String photoId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final Uint8List bytes;
  final String source;
}

abstract interface class BuildingCoverPhotoApiService {
  Future<void> updateBuildingCoverPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  });

  Future<Map<String, BuildingCoverThumbnailData>> getCoverPhotoThumbnails({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required List<String> photoIds,
  });

  void close();
}

class HttpBuildingCoverPhotoApiService implements BuildingCoverPhotoApiService {
  HttpBuildingCoverPhotoApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 45);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<void> updateBuildingCoverPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) async {
    await _post(
      action: 'updateBuildingCoverPhoto',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'buildingId': buildingId, 'photoId': photoId},
    );
  }

  @override
  Future<Map<String, BuildingCoverThumbnailData>> getCoverPhotoThumbnails({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required List<String> photoIds,
  }) async {
    if (photoIds.isEmpty) {
      return const <String, BuildingCoverThumbnailData>{};
    }

    final Map<String, dynamic> response = await _post(
      action: 'getCoverPhotoThumbnails',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'photoIds': photoIds},
    );

    final Object? rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const BuildingCoverPhotoApiException('代表写真サムネイルの応答にdataがありません。');
    }
    final Object? rawThumbnails = rawData['thumbnails'];
    if (rawThumbnails is! List<dynamic>) {
      throw const BuildingCoverPhotoApiException('代表写真サムネイルの応答形式が正しくありません。');
    }

    try {
      final Map<String, BuildingCoverThumbnailData> result =
          <String, BuildingCoverThumbnailData>{};
      for (final Object? item in rawThumbnails) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('thumbnailsの要素がJSONオブジェクトではありません。');
        }
        final BuildingCoverThumbnailData thumbnail =
            BuildingCoverThumbnailData.fromJson(item);
        result[thumbnail.photoId] = thumbnail;
      }
      return result;
    } on FormatException catch (error) {
      throw BuildingCoverPhotoApiException(
        '代表写真サムネイルの応答を読み取れませんでした。${error.message}',
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
        throw BuildingCoverPhotoApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BuildingCoverPhotoApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw BuildingCoverPhotoApiException(
          _optionalString(decoded['message']) ?? '代表写真を処理できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const BuildingCoverPhotoApiException(
        'Apps Scriptから時間内に応答がありませんでした。',
      );
    } on FormatException catch (error) {
      throw BuildingCoverPhotoApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const BuildingCoverPhotoApiException(
        'Apps Scriptへ接続できませんでした。ブラウザまたは社内ネットワークの制限を確認してください。',
      );
    }
  }

  @override
  void close() {
    _client.close();
  }
}

class BuildingCoverPhotoApiException implements Exception {
  const BuildingCoverPhotoApiException(
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

String _requiredString(Object? value, String fieldName) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$fieldNameがありません。');
  }
  return value.trim();
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

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String result = value.trim();
  return result.isEmpty ? null : result;
}
