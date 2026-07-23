import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class DriveSpikeUploadResponse {
  const DriveSpikeUploadResponse({
    required this.requestId,
    required this.serverTime,
    required this.storageFileId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.duplicate,
    required this.sharingAccess,
    required this.stage,
  });

  factory DriveSpikeUploadResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _requiredData(json);

    return DriveSpikeUploadResponse(
      requestId: _optionalString(json['requestId']),
      serverTime: _requiredString(json['serverTime'], 'serverTime'),
      storageFileId: _requiredString(data['storageFileId'], 'storageFileId'),
      fileName: _requiredString(data['fileName'], 'fileName'),
      mimeType: _requiredString(data['mimeType'], 'mimeType'),
      byteSize: _requiredInt(data['byteSize'], 'byteSize'),
      duplicate: data['duplicate'] == true,
      sharingAccess: _requiredString(data['sharingAccess'], 'sharingAccess'),
      stage: _requiredString(data['stage'], 'stage'),
    );
  }

  final String? requestId;
  final String serverTime;
  final String storageFileId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final bool duplicate;
  final String sharingAccess;
  final String stage;
}

@immutable
class DriveSpikePhotoData {
  const DriveSpikePhotoData({
    required this.requestId,
    required this.serverTime,
    required this.storageFileId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.sharingAccess,
    required this.stage,
    required this.bytes,
  });

  factory DriveSpikePhotoData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _requiredData(json);
    final String base64Data = _requiredString(data['base64Data'], 'base64Data');

    Uint8List bytes;
    try {
      bytes = base64Decode(base64Data);
    } on FormatException {
      throw const FormatException('base64Dataが正しいBase64ではありません。');
    }

    final int byteSize = _requiredInt(data['byteSize'], 'byteSize');
    if (bytes.length != byteSize) {
      throw const FormatException('画像データのサイズが応答値と一致しません。');
    }

    return DriveSpikePhotoData(
      requestId: _optionalString(json['requestId']),
      serverTime: _requiredString(json['serverTime'], 'serverTime'),
      storageFileId: _requiredString(data['storageFileId'], 'storageFileId'),
      fileName: _requiredString(data['fileName'], 'fileName'),
      mimeType: _requiredString(data['mimeType'], 'mimeType'),
      byteSize: byteSize,
      sharingAccess: _requiredString(data['sharingAccess'], 'sharingAccess'),
      stage: _requiredString(data['stage'], 'stage'),
      bytes: bytes,
    );
  }

  final String? requestId;
  final String serverTime;
  final String storageFileId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String sharingAccess;
  final String stage;
  final Uint8List bytes;
}

Map<String, dynamic> _requiredData(Map<String, dynamic> json) {
  if (json['ok'] != true) {
    throw FormatException(
      _optionalString(json['message']) ?? 'API応答が失敗を示しています。',
    );
  }

  final Object? rawData = json['data'];
  if (rawData is! Map<String, dynamic>) {
    throw const FormatException('dataがJSONオブジェクトではありません。');
  }

  return rawData;
}

String _requiredString(Object? value, String fieldName) {
  final String? result = _optionalString(value);
  if (result == null) {
    throw FormatException('$fieldNameがありません。');
  }
  return result;
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
