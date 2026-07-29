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
class UploadRecordPhotoResult {
  const UploadRecordPhotoResult({
    required this.photoId,
    required this.storageFileId,
    required this.byteSize,
    required this.displayOrder,
    required this.reused,
  });

  factory UploadRecordPhotoResult.fromJson(Map<String, dynamic> json) {
    return UploadRecordPhotoResult(
      photoId: _requiredString(json['photoId'], 'photoId'),
      storageFileId: _requiredString(json['storageFileId'], 'storageFileId'),
      byteSize: _requiredInt(json['byteSize'], 'byteSize'),
      displayOrder: _requiredInt(json['displayOrder'], 'displayOrder'),
      reused: json['reused'] == true,
    );
  }

  final String photoId;
  final String storageFileId;
  final int byteSize;
  final int displayOrder;
  final bool reused;
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
