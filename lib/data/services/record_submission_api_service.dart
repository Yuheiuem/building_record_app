import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/record_submission_result.dart';
import 'record_thumbnail_service.dart';

class RecordPreparationPayload {
  const RecordPreparationPayload({
    required this.requestId,
    required this.buildingMode,
    required this.buildingId,
    required this.visitId,
    required this.buildingName,
    required this.designTagIds,
    required this.salesTagIds,
    required this.constructionTagIds,
    required this.visitedAt,
    required this.triggerTagIds,
    required this.impression,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationSource,
    required this.expectedPhotoCount,
  });

  final String requestId;
  final String buildingMode;
  final String buildingId;
  final String visitId;
  final String? buildingName;
  final List<String> designTagIds;
  final List<String> salesTagIds;
  final List<String> constructionTagIds;
  final DateTime visitedAt;
  final List<String> triggerTagIds;
  final String impression;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String locationSource;
  final int expectedPhotoCount;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'buildingMode': buildingMode,
      'buildingId': buildingId,
      'visitId': visitId,
      'buildingName': buildingName,
      'designTagIds': designTagIds,
      'salesTagIds': salesTagIds,
      'constructionTagIds': constructionTagIds,
      'visitedAt': visitedAt.toIso8601String(),
      'triggerTagIds': triggerTagIds,
      'impression': impression,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyM': accuracyM,
      'locationSource': locationSource,
      'expectedPhotoCount': expectedPhotoCount,
    };
  }
}

abstract interface class RecordSubmissionApiService {
  Future<BeginRecordResult> beginRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingMode,
    required String buildingId,
    required String visitId,
    required String? buildingName,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int expectedPhotoCount,
  });

  Future<UploadRecordPhotoResult> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required DateTime takenAt,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int displayOrder,
    RecordPreparationPayload? recordPreparation,
    bool finalizeAfterUpload = false,
  });

  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  });

  void close();
}

class HttpRecordSubmissionApiService implements RecordSubmissionApiService {
  HttpRecordSubmissionApiService({
    http.Client? client,
    Uri? endpoint,
    RecordThumbnailService? thumbnailService,
    Duration deferredThumbnailQuietDelay = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse(AppConfig.appsScriptWebAppUrl),
       _thumbnailService =
           thumbnailService ?? const ImageRecordThumbnailService(),
       _deferredThumbnailQuietDelay = deferredThumbnailQuietDelay;

  static const Duration _normalTimeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 60);

  final http.Client _client;
  final Uri _endpoint;
  final RecordThumbnailService _thumbnailService;
  final Duration _deferredThumbnailQuietDelay;
  final List<_DeferredThumbnailUpload> _deferredThumbnailUploads =
      <_DeferredThumbnailUpload>[];

  int _activePrimaryRequests = 0;
  bool _thumbnailDrainScheduled = false;
  bool _thumbnailDrainRunning = false;
  bool _closed = false;

  @override
  Future<BeginRecordResult> beginRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingMode,
    required String buildingId,
    required String visitId,
    required String? buildingName,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int expectedPhotoCount,
  }) async {
    return _runPrimaryRequest<BeginRecordResult>(() async {
      final Map<String, dynamic> response = await _post(
        action: 'beginRecord',
        requestId: requestId,
        clientVersion: clientVersion,
        idToken: idToken,
        payload: <String, Object?>{
          'buildingMode': buildingMode,
          'buildingId': buildingId,
          'visitId': visitId,
          'buildingName': buildingName,
          'designTagIds': designTagIds,
          'salesTagIds': salesTagIds,
          'constructionTagIds': constructionTagIds,
          'visitedAt': visitedAt.toIso8601String(),
          'triggerTagIds': triggerTagIds,
          'impression': impression,
          'latitude': latitude,
          'longitude': longitude,
          'accuracyM': accuracyM,
          'locationSource': locationSource,
          'expectedPhotoCount': expectedPhotoCount,
        },
        timeout: _normalTimeout,
      );
      return BeginRecordResult.fromJson(_requiredData(response));
    });
  }

  @override
  Future<UploadRecordPhotoResult> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required DateTime takenAt,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int displayOrder,
    RecordPreparationPayload? recordPreparation,
    bool finalizeAfterUpload = false,
  }) async {
    final Stopwatch preparationStopwatch = Stopwatch()..start();
    final Stopwatch originalBase64Stopwatch = Stopwatch()..start();
    final String base64Data = base64Encode(bytes);
    originalBase64Stopwatch.stop();
    preparationStopwatch.stop();

    final Stopwatch requestStopwatch = Stopwatch()..start();
    final Map<String, dynamic> response =
        await _runPrimaryRequest<Map<String, dynamic>>(() {
          return _post(
            action: 'uploadPhoto',
            requestId: requestId,
            clientVersion: clientVersion,
            idToken: idToken,
            payload: <String, Object?>{
              'buildingId': buildingId,
              'visitId': visitId,
              'photoId': photoId,
              'fileName': fileName,
              'mimeType': mimeType,
              'byteSize': bytes.length,
              'base64Data': base64Data,
              'takenAt': takenAt.toIso8601String(),
              'latitude': latitude,
              'longitude': longitude,
              'accuracyM': accuracyM,
              'locationSource': locationSource,
              'displayOrder': displayOrder,
              if (recordPreparation != null)
                'recordDraft': recordPreparation.toJson(),
              if (finalizeAfterUpload) 'finalizeAfterUpload': true,
            },
            timeout: _uploadTimeout,
          );
        });
    requestStopwatch.stop();

    final UploadRecordPhotoResult result = UploadRecordPhotoResult.fromJson(
      _requiredData(response),
      clientEncodeMs: preparationStopwatch.elapsedMilliseconds,
      clientRequestMs: requestStopwatch.elapsedMilliseconds,
      clientOriginalBase64Ms: originalBase64Stopwatch.elapsedMilliseconds,
      clientThumbnailCreateMs: 0,
      clientThumbnailBase64Ms: 0,
    );

    unawaited(
      _prepareDeferredThumbnail(
        requestId: requestId,
        clientVersion: clientVersion,
        idToken: idToken,
        buildingId: buildingId,
        visitId: visitId,
        photoId: photoId,
        sourceBytes: bytes,
      ),
    );

    return result;
  }

  Future<RecordThumbnailData?> _createThumbnailSafely(Uint8List bytes) async {
    try {
      return await _thumbnailService.createThumbnail(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _prepareDeferredThumbnail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required String photoId,
    required Uint8List sourceBytes,
  }) async {
    if (_closed) {
      return;
    }

    final RecordThumbnailData? thumbnail = await _createThumbnailSafely(
      sourceBytes,
    );
    if (_closed || thumbnail == null) {
      return;
    }

    _deferredThumbnailUploads.removeWhere(
      (_DeferredThumbnailUpload item) => item.photoId == photoId,
    );
    _deferredThumbnailUploads.add(
      _DeferredThumbnailUpload(
        requestId: '$requestId-thumbnail',
        clientVersion: clientVersion,
        idToken: idToken,
        buildingId: buildingId,
        visitId: visitId,
        photoId: photoId,
        thumbnail: thumbnail,
      ),
    );
    _scheduleDeferredThumbnailDrain();
  }

  Future<T> _runPrimaryRequest<T>(Future<T> Function() action) async {
    _activePrimaryRequests += 1;
    try {
      return await action();
    } finally {
      _activePrimaryRequests -= 1;
      _scheduleDeferredThumbnailDrain();
    }
  }

  void _scheduleDeferredThumbnailDrain() {
    if (_closed ||
        _deferredThumbnailUploads.isEmpty ||
        _thumbnailDrainScheduled ||
        _thumbnailDrainRunning) {
      return;
    }

    _thumbnailDrainScheduled = true;
    unawaited(
      Future<void>.delayed(_deferredThumbnailQuietDelay, () async {
        _thumbnailDrainScheduled = false;
        if (_closed || _deferredThumbnailUploads.isEmpty) {
          return;
        }
        if (_activePrimaryRequests > 0) {
          _scheduleDeferredThumbnailDrain();
          return;
        }
        await _drainDeferredThumbnails();
      }),
    );
  }

  Future<void> _drainDeferredThumbnails() async {
    if (_closed || _thumbnailDrainRunning) {
      return;
    }

    _thumbnailDrainRunning = true;
    try {
      while (!_closed &&
          _activePrimaryRequests == 0 &&
          _deferredThumbnailUploads.isNotEmpty) {
        final _DeferredThumbnailUpload item = _deferredThumbnailUploads
            .removeAt(0);
        try {
          await _post(
            action: 'uploadPhotoThumbnail',
            requestId: item.requestId,
            clientVersion: item.clientVersion,
            idToken: item.idToken,
            payload: <String, Object?>{
              'buildingId': item.buildingId,
              'visitId': item.visitId,
              'photoId': item.photoId,
              'thumbnailMimeType': item.thumbnail.mimeType,
              'thumbnailByteSize': item.thumbnail.byteSize,
              'thumbnailBase64Data': base64Encode(item.thumbnail.bytes),
            },
            timeout: _uploadTimeout,
          );
        } catch (_) {
          // サムネイル後送信は記録保存の成否に影響させない。
          // 未作成分は既存のメンテナンス処理で後から補完できる。
        }
      }
    } finally {
      _thumbnailDrainRunning = false;
      if (!_closed && _deferredThumbnailUploads.isNotEmpty) {
        _scheduleDeferredThumbnailDrain();
      }
    }
  }

  @override
  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    return _runPrimaryRequest<FinalizeRecordResult>(() async {
      final Map<String, dynamic> response = await _post(
        action: 'finalizeRecord',
        requestId: requestId,
        clientVersion: clientVersion,
        idToken: idToken,
        payload: <String, Object?>{
          'buildingId': buildingId,
          'visitId': visitId,
        },
        timeout: _normalTimeout,
      );
      return FinalizeRecordResult.fromJson(_requiredData(response));
    });
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
        throw RecordSubmissionApiException(
          'Apps ScriptがHTTP ${response.statusCode}を返しました。',
          statusCode: response.statusCode,
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const RecordSubmissionApiException(
          'Apps Scriptの応答がJSONオブジェクトではありません。',
        );
      }
      if (decoded['ok'] != true) {
        throw RecordSubmissionApiException(
          _optionalString(decoded['message']) ?? '記録を保存できませんでした。',
          errorCode: _optionalString(decoded['errorCode']),
        );
      }
      return decoded;
    } on TimeoutException {
      throw const RecordSubmissionApiException('Apps Scriptから時間内に応答がありませんでした。');
    } on FormatException catch (error) {
      throw RecordSubmissionApiException(
        'Apps Scriptの応答を読み取れませんでした。${error.message}',
      );
    } on http.ClientException {
      throw const RecordSubmissionApiException(
        'Apps Scriptへ接続できませんでした。ブラウザまたは社内ネットワークの制限を確認してください。',
      );
    }
  }

  Map<String, dynamic> _requiredData(Map<String, dynamic> response) {
    final Object? data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const RecordSubmissionApiException(
        'Apps ScriptのdataがJSONオブジェクトではありません。',
      );
    }
    return data;
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
    _closed = true;
    _deferredThumbnailUploads.clear();
    _client.close();
  }
}

class _DeferredThumbnailUpload {
  const _DeferredThumbnailUpload({
    required this.requestId,
    required this.clientVersion,
    required this.idToken,
    required this.buildingId,
    required this.visitId,
    required this.photoId,
    required this.thumbnail,
  });

  final String requestId;
  final String clientVersion;
  final String idToken;
  final String buildingId;
  final String visitId;
  final String photoId;
  final RecordThumbnailData thumbnail;
}

class RecordSubmissionApiException implements Exception {
  const RecordSubmissionApiException(
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
