import 'package:flutter/foundation.dart';

@immutable
class BeginRecordResult {
  const BeginRecordResult({
    required this.buildingId,
    required this.visitId,
    required this.expectedPhotoCount,
    required this.buildingCreated,
    required this.visitCreated,
    required this.reused,
  });

  factory BeginRecordResult.fromJson(Map<String, dynamic> json) {
    return BeginRecordResult(
      buildingId: _requiredString(json['buildingId'], 'buildingId'),
      visitId: _requiredString(json['visitId'], 'visitId'),
      expectedPhotoCount: _requiredInt(
        json['expectedPhotoCount'],
        'expectedPhotoCount',
      ),
      buildingCreated: json['buildingCreated'] == true,
      visitCreated: json['visitCreated'] == true,
      reused: json['reused'] == true,
    );
  }

  final String buildingId;
  final String visitId;
  final int expectedPhotoCount;
  final bool buildingCreated;
  final bool visitCreated;
  final bool reused;
}

@immutable
class RecordUploadPerformance {
  const RecordUploadPerformance({
    required this.clientEncodeMs,
    required this.clientRequestMs,
    required this.authenticationMode,
    required this.authenticationMs,
    required this.lockWaitMs,
    required this.lookupMs,
    required this.base64DecodeMs,
    required this.driveSaveMs,
    required this.sheetWriteMs,
    this.clientOriginalBase64Ms = 0,
    this.clientThumbnailCreateMs = 0,
    this.clientThumbnailBase64Ms = 0,
    this.spreadsheetOpenMs,
    this.responseCacheMs,
    this.thumbnailBase64DecodeMs,
    this.thumbnailDriveSaveMs,
    this.draftPreparationMs,
    this.finalizeMs,
    required this.handlerTotalMs,
  });

  factory RecordUploadPerformance.fromJson(
    Map<String, dynamic>? json, {
    required int clientEncodeMs,
    required int clientRequestMs,
    int clientOriginalBase64Ms = 0,
    int clientThumbnailCreateMs = 0,
    int clientThumbnailBase64Ms = 0,
  }) {
    final Map<String, dynamic> safe = json ?? const <String, dynamic>{};
    return RecordUploadPerformance(
      clientEncodeMs: clientEncodeMs,
      clientRequestMs: clientRequestMs,
      clientOriginalBase64Ms: clientOriginalBase64Ms,
      clientThumbnailCreateMs: clientThumbnailCreateMs,
      clientThumbnailBase64Ms: clientThumbnailBase64Ms,
      authenticationMode: _optionalString(safe['authenticationMode']),
      authenticationMs: _optionalInt(safe['authenticationMs']),
      lockWaitMs: _optionalInt(safe['lockWaitMs']),
      spreadsheetOpenMs: _optionalInt(safe['spreadsheetOpenMs']),
      responseCacheMs: _optionalInt(safe['responseCacheMs']),
      lookupMs: _optionalInt(safe['lookupMs']),
      base64DecodeMs: _optionalInt(safe['base64DecodeMs']),
      thumbnailBase64DecodeMs: _optionalInt(safe['thumbnailBase64DecodeMs']),
      driveSaveMs: _optionalInt(safe['driveSaveMs']),
      thumbnailDriveSaveMs: _optionalInt(safe['thumbnailDriveSaveMs']),
      sheetWriteMs: _optionalInt(safe['sheetWriteMs']),
      draftPreparationMs: _optionalInt(safe['draftPreparationMs']),
      finalizeMs: _optionalInt(safe['finalizeMs']),
      handlerTotalMs: _optionalInt(safe['handlerTotalMs']),
    );
  }

  final int clientEncodeMs;
  final int clientRequestMs;
  final int clientOriginalBase64Ms;
  final int clientThumbnailCreateMs;
  final int clientThumbnailBase64Ms;
  final String? authenticationMode;
  final int? authenticationMs;
  final int? lockWaitMs;
  final int? spreadsheetOpenMs;
  final int? responseCacheMs;
  final int? lookupMs;
  final int? base64DecodeMs;
  final int? thumbnailBase64DecodeMs;
  final int? driveSaveMs;
  final int? thumbnailDriveSaveMs;
  final int? sheetWriteMs;
  final int? draftPreparationMs;
  final int? finalizeMs;
  final int? handlerTotalMs;

  Duration get clientEncodeDuration => Duration(milliseconds: clientEncodeMs);
  Duration get clientRequestDuration => Duration(milliseconds: clientRequestMs);
  Duration get clientTotalDuration =>
      Duration(milliseconds: clientEncodeMs + clientRequestMs);

  bool get hasClientBreakdown =>
      clientOriginalBase64Ms > 0 ||
      clientThumbnailCreateMs > 0 ||
      clientThumbnailBase64Ms > 0;

  bool get hasServerBreakdown =>
      authenticationMode != null ||
      authenticationMs != null ||
      handlerTotalMs != null;
}

@immutable
class UploadRecordPhotoResult {
  const UploadRecordPhotoResult({
    required this.photoId,
    required this.storageFileId,
    required this.byteSize,
    required this.displayOrder,
    required this.reused,
    this.buildingId,
    this.visitId,
    this.recordPrepared = false,
    this.buildingCreated = false,
    this.visitCreated = false,
    this.recordCompleted = false,
    this.photoCount,
    this.saveMode,
    this.performance,
  });

  factory UploadRecordPhotoResult.fromJson(
    Map<String, dynamic> json, {
    int clientEncodeMs = 0,
    int clientRequestMs = 0,
    int clientOriginalBase64Ms = 0,
    int clientThumbnailCreateMs = 0,
    int clientThumbnailBase64Ms = 0,
  }) {
    final Object? performanceJson = json['performance'];
    return UploadRecordPhotoResult(
      photoId: _requiredString(json['photoId'], 'photoId'),
      storageFileId: _requiredString(json['storageFileId'], 'storageFileId'),
      byteSize: _requiredInt(json['byteSize'], 'byteSize'),
      displayOrder: _requiredInt(json['displayOrder'], 'displayOrder'),
      reused: json['reused'] == true,
      buildingId: _optionalString(json['buildingId']),
      visitId: _optionalString(json['visitId']),
      recordPrepared: json['recordPrepared'] == true,
      buildingCreated: json['buildingCreated'] == true,
      visitCreated: json['visitCreated'] == true,
      recordCompleted: json['recordCompleted'] == true,
      photoCount: _optionalInt(json['photoCount']),
      saveMode: _optionalString(json['saveMode']),
      performance: RecordUploadPerformance.fromJson(
        performanceJson is Map<String, dynamic> ? performanceJson : null,
        clientEncodeMs: clientEncodeMs,
        clientRequestMs: clientRequestMs,
        clientOriginalBase64Ms: clientOriginalBase64Ms,
        clientThumbnailCreateMs: clientThumbnailCreateMs,
        clientThumbnailBase64Ms: clientThumbnailBase64Ms,
      ),
    );
  }

  final String photoId;
  final String storageFileId;
  final int byteSize;
  final int displayOrder;
  final bool reused;
  final String? buildingId;
  final String? visitId;
  final bool recordPrepared;
  final bool buildingCreated;
  final bool visitCreated;
  final bool recordCompleted;
  final int? photoCount;
  final String? saveMode;
  final RecordUploadPerformance? performance;
}

@immutable
class FinalizeRecordResult {
  const FinalizeRecordResult({
    required this.buildingId,
    required this.visitId,
    required this.photoCount,
    required this.status,
    required this.reused,
  });

  factory FinalizeRecordResult.fromJson(Map<String, dynamic> json) {
    return FinalizeRecordResult(
      buildingId: _requiredString(json['buildingId'], 'buildingId'),
      visitId: _requiredString(json['visitId'], 'visitId'),
      photoCount: _requiredInt(json['photoCount'], 'photoCount'),
      status: _requiredString(json['status'], 'status'),
      reused: json['reused'] == true,
    );
  }

  final String buildingId;
  final String visitId;
  final int photoCount;
  final String status;
  final bool reused;
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

int? _optionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String result = value.trim();
  return result.isEmpty ? null : result;
}
