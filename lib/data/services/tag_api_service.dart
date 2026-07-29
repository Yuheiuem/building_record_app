import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/building_tag.dart';
import '../models/tag_creation_result.dart';

abstract interface class TagApiService {
  Future<TagCreationResult> createTag({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required BuildingTagType tagType,
    required String tagName,
  });

  void close();
}

class HttpTagApiService implements TagApiService {
  HttpTagApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<TagCreationResult> createTag({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required BuildingTagType tagType,
    required String tagName,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': 'createTag',
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': <String, Object?>{
        'tagType': tagType.apiValue,
        'tagName': tagName,
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
        throw TagApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const TagApiException('Apps Scriptの応答がJSONオブジェクトではありません。');
      }

      if (decoded['ok'] != true) {
        throw TagApiException(
          _optionalString(decoded['message']) ?? 'タグを追加できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }

      final Object? rawData = decoded['data'];
      if (rawData is! Map<String, dynamic>) {
        throw const TagApiException('Apps ScriptのdataがJSONオブジェクトではありません。');
      }

      return TagCreationResult.fromJson(rawData);
    } on TimeoutException {
      throw const TagApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw TagApiException('Apps Scriptの応答を読み取れませんでした。${error.message}');
    } on http.ClientException {
      throw const TagApiException(
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

class TagApiException implements Exception {
  const TagApiException(this.message, {this.statusCode, this.errorCode});

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() => message;
}
