import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class StorageUsageSummary {
  const StorageUsageSummary({
    required this.quotaLimitBytes,
    required this.quotaUsageBytes,
    required this.driveUsageBytes,
    required this.driveTrashBytes,
    required this.appOriginalBytes,
    required this.appStoredPhotoCount,
    required this.appActivePhotoCount,
    required this.appHiddenPhotoCount,
  });

  factory StorageUsageSummary.fromJson(Map<String, dynamic> json) {
    final Object? rawQuota = json['quota'];
    final Object? rawApp = json['app'];
    if (rawQuota is! Map<String, dynamic>) {
      throw const FormatException('quotaがJSONオブジェクトではありません。');
    }
    if (rawApp is! Map<String, dynamic>) {
      throw const FormatException('appがJSONオブジェクトではありません。');
    }

    return StorageUsageSummary(
      quotaLimitBytes: _optionalInt(rawQuota['limitBytes'], 'quota.limitBytes'),
      quotaUsageBytes: _requiredInt(rawQuota['usageBytes'], 'quota.usageBytes'),
      driveUsageBytes: _requiredInt(
        rawQuota['usageInDriveBytes'],
        'quota.usageInDriveBytes',
      ),
      driveTrashBytes: _requiredInt(
        rawQuota['usageInDriveTrashBytes'],
        'quota.usageInDriveTrashBytes',
      ),
      appOriginalBytes: _requiredInt(
        rawApp['originalPhotoBytes'],
        'app.originalPhotoBytes',
      ),
      appStoredPhotoCount: _requiredInt(
        rawApp['storedPhotoCount'],
        'app.storedPhotoCount',
      ),
      appActivePhotoCount: _requiredInt(
        rawApp['activePhotoCount'],
        'app.activePhotoCount',
      ),
      appHiddenPhotoCount: _requiredInt(
        rawApp['hiddenPhotoCount'],
        'app.hiddenPhotoCount',
      ),
    );
  }

  final int? quotaLimitBytes;
  final int quotaUsageBytes;
  final int driveUsageBytes;
  final int driveTrashBytes;
  final int appOriginalBytes;
  final int appStoredPhotoCount;
  final int appActivePhotoCount;
  final int appHiddenPhotoCount;

  double? get usageRatio {
    final int? limit = quotaLimitBytes;
    if (limit == null || limit <= 0) {
      return null;
    }
    return quotaUsageBytes / limit;
  }

  int? get remainingBytes {
    final int? limit = quotaLimitBytes;
    if (limit == null) {
      return null;
    }
    return (limit - quotaUsageBytes).clamp(0, limit).toInt();
  }
}

abstract interface class StorageMonitorApiService {
  Future<StorageUsageSummary> getStorageUsage({
    required String requestId,
    required String clientVersion,
    required String idToken,
  });

  void close();
}

class HttpStorageMonitorApiService implements StorageMonitorApiService {
  HttpStorageMonitorApiService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl);

  static const Duration _requestTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<StorageUsageSummary> getStorageUsage({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    final Map<String, dynamic> response = await _post(
      action: 'getStorageUsage',
      requestId: requestId,
      clientVersion: clientVersion,
      idToken: idToken,
    );
    final Object? rawData = response['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const StorageMonitorApiException('Apps Scriptの応答にdataがありません。');
    }

    try {
      return StorageUsageSummary.fromJson(rawData);
    } on FormatException catch (error) {
      throw StorageMonitorApiException('容量情報の応答を読み取れませんでした。${error.message}');
    }
  }

  Future<Map<String, dynamic>> _post({
    required String action,
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    final String requestBody = jsonEncode(<String, Object?>{
      'action': action,
      'requestId': requestId,
      'idToken': idToken,
      'clientVersion': clientVersion,
      'payload': const <String, Object?>{},
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
        throw StorageMonitorApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const StorageMonitorApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw StorageMonitorApiException(
          _optionalString(decoded['message']) ?? '容量情報を取得できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const StorageMonitorApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw StorageMonitorApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const StorageMonitorApiException(
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

class StorageMonitorApiException implements Exception {
  const StorageMonitorApiException(
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
  final int? result = _optionalInt(value, fieldName);
  if (result == null) {
    throw FormatException('$fieldNameがありません。');
  }
  return result;
}

int? _optionalInt(Object? value, String fieldName) {
  if (value == null || value == '') {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$fieldNameが数値ではありません。');
}
