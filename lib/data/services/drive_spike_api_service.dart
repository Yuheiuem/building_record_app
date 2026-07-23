import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/drive_spike_photo.dart';

abstract interface class DriveSpikeApiService {
  Future<DriveSpikeUploadResponse> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  });

  Future<DriveSpikePhotoData> getPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String storageFileId,
  });

  void close();
}

class HttpDriveSpikeApiService implements DriveSpikeApiService {
  HttpDriveSpikeApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _uploadTimeout = Duration(seconds: 45);
  static const Duration _downloadTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<DriveSpikeUploadResponse> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final Map<String, dynamic> responseJson = await _post(
      action: 'uploadSpikePhoto',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{
        'photoId': photoId,
        'fileName': fileName,
        'mimeType': mimeType,
        'byteSize': bytes.length,
        'base64Data': base64Encode(bytes),
      },
      timeout: _uploadTimeout,
    );

    return DriveSpikeUploadResponse.fromJson(responseJson);
  }

  @override
  Future<DriveSpikePhotoData> getPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String storageFileId,
  }) async {
    final Map<String, dynamic> responseJson = await _post(
      action: 'getSpikePhoto',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
      payload: <String, Object?>{'storageFileId': storageFileId},
      timeout: _downloadTimeout,
    );

    return DriveSpikePhotoData.fromJson(responseJson);
  }

  Future<Map<String, dynamic>> _post({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
    required Map<String, Object?> payload,
    required Duration timeout,
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
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DriveSpikeApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const DriveSpikeApiException('Apps Scriptの応答がJSONオブジェクトではありません。');
      }

      if (decoded['ok'] != true) {
        throw DriveSpikeApiException(
          _optionalString(decoded['message']) ?? 'Apps Scriptの処理に失敗しました。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }

      return decoded;
    } on TimeoutException {
      throw const DriveSpikeApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw DriveSpikeApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const DriveSpikeApiException(
        'Apps Scriptへ接続できませんでした。ブラウザまたは社内ネットワークの制限を確認してください。',
      );
    }
  }

  String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void close() {
    _client.close();
  }
}

class DriveSpikeApiException implements Exception {
  const DriveSpikeApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}
