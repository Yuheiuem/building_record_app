import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/data/services/record_thumbnail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uploadPhoto本体にはサムネイルを同梱せず後送信する', () async {
    final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
    final Completer<void> deferredRequestSeen = Completer<void>();

    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> requestJson =
          jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(requestJson);

      if (requestJson['action'] == 'uploadPhotoThumbnail') {
        if (!deferredRequestSeen.isCompleted) {
          deferredRequestSeen.complete();
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'data': <String, Object?>{
              'photoId': 'photo-12345678',
              'thumbnailFileId': 'thumbnail-file-id',
              'reused': false,
            },
          }),
          200,
        );
      }

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
          thumbnailService: _FakeThumbnailService(
            RecordThumbnailData(
              bytes: Uint8List.fromList(<int>[9, 8, 7]),
              mimeType: 'image/jpeg',
              width: 480,
              height: 320,
            ),
          ),
          deferredThumbnailQuietDelay: Duration.zero,
        );
    addTearDown(service.close);

    await service.uploadPhoto(
      requestId: 'request-12345678',
      clientVersion: 'v0.19.4',
      idToken: 'token',
      buildingId: 'building-12345678',
      visitId: 'visit-12345678',
      photoId: 'photo-12345678',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      takenAt: DateTime.utc(2026, 8, 18),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 5,
      locationSource: 'gps',
      displayOrder: 1,
    );

    await deferredRequestSeen.future.timeout(const Duration(seconds: 1));

    expect(requests.length, 2);
    expect(requests.first['action'], 'uploadPhoto');

    final Map<String, dynamic> primaryPayload =
        requests.first['payload'] as Map<String, dynamic>;
    expect(primaryPayload['base64Data'], base64Encode(<int>[1, 2, 3, 4]));
    expect(primaryPayload.containsKey('thumbnailMimeType'), isFalse);
    expect(primaryPayload.containsKey('thumbnailByteSize'), isFalse);
    expect(primaryPayload.containsKey('thumbnailBase64Data'), isFalse);

    expect(requests.last['action'], 'uploadPhotoThumbnail');
    final Map<String, dynamic> thumbnailPayload =
        requests.last['payload'] as Map<String, dynamic>;
    expect(thumbnailPayload['buildingId'], 'building-12345678');
    expect(thumbnailPayload['visitId'], 'visit-12345678');
    expect(thumbnailPayload['photoId'], 'photo-12345678');
    expect(thumbnailPayload['thumbnailMimeType'], 'image/jpeg');
    expect(thumbnailPayload['thumbnailByteSize'], 3);
    expect(
      thumbnailPayload['thumbnailBase64Data'],
      base64Encode(<int>[9, 8, 7]),
    );
  });

  test('サムネイル生成失敗時も元写真だけを送信する', () async {
    final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> requestJson =
          jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(requestJson);
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
          deferredThumbnailQuietDelay: Duration.zero,
        );
    addTearDown(service.close);

    await service.uploadPhoto(
      requestId: 'request-12345678',
      clientVersion: 'v0.19.4',
      idToken: 'token',
      buildingId: 'building-12345678',
      visitId: 'visit-12345678',
      photoId: 'photo-12345678',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      takenAt: DateTime.utc(2026, 8, 18),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: null,
      locationSource: 'manual',
      displayOrder: 1,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(requests.length, 1);
    expect(requests.single['action'], 'uploadPhoto');
    final Map<String, dynamic> payload =
        requests.single['payload'] as Map<String, dynamic>;
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
