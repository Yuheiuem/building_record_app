import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/data/services/record_thumbnail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uploadPhotoへサムネイルを同梱する', () async {
    late Map<String, dynamic> requestJson;
    final MockClient client = MockClient((http.Request request) async {
      requestJson = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'data': <String, Object?>{
            'photoId': 'photo-12345678',
            'storageFileId': 'original-file-id',
            'thumbnailFileId': 'thumbnail-file-id',
            'byteSize': 4,
            'displayOrder': 1,
            'reused': false,
          },
        }),
        200,
      );
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
          thumbnailService: _FakeThumbnailService(
            RecordThumbnailData(
              bytes: Uint8List.fromList(<int>[9, 8, 7]),
              mimeType: 'image/jpeg',
              width: 480,
              height: 320,
            ),
          ),
        );

    addTearDown(service.close);

    await service.uploadPhoto(
      requestId: 'request-12345678',
      clientVersion: 'v0.17.0',
      idToken: 'token',
      buildingId: 'building-12345678',
      visitId: 'visit-12345678',
      photoId: 'photo-12345678',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      takenAt: DateTime.utc(2026, 8, 4),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 5,
      locationSource: 'gps',
      displayOrder: 1,
    );

    final Map<String, dynamic> payload =
        requestJson['payload'] as Map<String, dynamic>;
    expect(payload['thumbnailMimeType'], 'image/jpeg');
    expect(payload['thumbnailByteSize'], 3);
    expect(payload['thumbnailBase64Data'], base64Encode(<int>[9, 8, 7]));
  });

  test('サムネイル生成失敗時も元写真だけを送信する', () async {
    late Map<String, dynamic> requestJson;
    final MockClient client = MockClient((http.Request request) async {
      requestJson = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'data': <String, Object?>{
            'photoId': 'photo-12345678',
            'storageFileId': 'original-file-id',
            'byteSize': 4,
            'displayOrder': 1,
            'reused': false,
          },
        }),
        200,
      );
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
          thumbnailService: const _ThrowingThumbnailService(),
        );

    addTearDown(service.close);

    await service.uploadPhoto(
      requestId: 'request-12345678',
      clientVersion: 'v0.17.0',
      idToken: 'token',
      buildingId: 'building-12345678',
      visitId: 'visit-12345678',
      photoId: 'photo-12345678',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      takenAt: DateTime.utc(2026, 8, 4),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: null,
      locationSource: 'manual',
      displayOrder: 1,
    );

    final Map<String, dynamic> payload =
        requestJson['payload'] as Map<String, dynamic>;
    expect(payload['base64Data'], base64Encode(<int>[1, 2, 3, 4]));
    expect(payload.containsKey('thumbnailMimeType'), isFalse);
    expect(payload.containsKey('thumbnailByteSize'), isFalse);
    expect(payload.containsKey('thumbnailBase64Data'), isFalse);
  });
}

class _FakeThumbnailService implements RecordThumbnailService {
  const _FakeThumbnailService(this.result);

  final RecordThumbnailData? result;

  @override
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes) async {
    return result;
  }
}

class _ThrowingThumbnailService implements RecordThumbnailService {
  const _ThrowingThumbnailService();

  @override
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes) {
    throw StateError('thumbnail error');
  }
}
