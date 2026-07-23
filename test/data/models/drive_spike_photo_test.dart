import 'dart:convert';

import 'package:building_record_app/data/models/drive_spike_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Drive保存応答を変換できる', () {
    final DriveSpikeUploadResponse response = DriveSpikeUploadResponse.fromJson(
      <String, dynamic>{
        'ok': true,
        'requestId': 'request-1',
        'serverTime': '2026-07-23T16:00:00+09:00',
        'data': <String, dynamic>{
          'storageFileId': 'drive-file-id',
          'fileName': 'spike_photo.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': 3,
          'duplicate': false,
          'sharingAccess': 'PRIVATE',
          'stage': '0-4',
        },
        'errorCode': null,
        'message': null,
      },
    );

    expect(response.storageFileId, 'drive-file-id');
    expect(response.mimeType, 'image/jpeg');
    expect(response.byteSize, 3);
    expect(response.duplicate, isFalse);
    expect(response.sharingAccess, 'PRIVATE');
  });

  test('Drive画像再取得応答のBase64を復元できる', () {
    final List<int> sourceBytes = <int>[1, 2, 3, 4];
    final DriveSpikePhotoData response = DriveSpikePhotoData.fromJson(
      <String, dynamic>{
        'ok': true,
        'requestId': 'request-2',
        'serverTime': '2026-07-23T16:00:01+09:00',
        'data': <String, dynamic>{
          'storageFileId': 'drive-file-id',
          'fileName': 'spike_photo.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': sourceBytes.length,
          'base64Data': base64Encode(sourceBytes),
          'sharingAccess': 'PRIVATE',
          'stage': '0-4',
        },
        'errorCode': null,
        'message': null,
      },
    );

    expect(response.bytes, sourceBytes);
    expect(response.sharingAccess, 'PRIVATE');
  });
}
