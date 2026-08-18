import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/data/services/record_thumbnail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('beginRecordで建物と訪問の下書きを送信する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-begin',
        'serverTime': '2026-07-29T16:00:00+09:00',
        'data': <String, dynamic>{
          'buildingId': 'building-1',
          'visitId': 'visit-1',
          'expectedPhotoCount': 2,
          'buildingCreated': true,
          'visitCreated': true,
          'reused': false,
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );
    final BeginRecordResult result = await service.beginRecord(
      requestId: 'request-begin',
      clientVersion: 'v0.13.2',
      idToken: 'test-id-token',
      buildingMode: 'new',
      buildingId: 'building-1',
      visitId: 'visit-1',
      buildingName: '第一ビル',
      designTagIds: const <String>['tag-design-1'],
      salesTagIds: const <String>[],
      constructionTagIds: const <String>['tag-construction-1'],
      visitedAt: DateTime.parse('2026-07-29T15:00:00+09:00'),
      triggerTagIds: const <String>['tag-trigger-1'],
      impression: '印象的だった。',
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      locationSource: 'gps',
      expectedPhotoCount: 2,
    );
    expect(sentBody['action'], 'beginRecord');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['buildingName'], '第一ビル');
    expect(payload['designTagIds'], <String>['tag-design-1']);
    expect(payload['expectedPhotoCount'], 2);
    expect(result.visitId, 'visit-1');
    service.close();
  });

  test('uploadPhotoでBase64画像と位置を送信する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _uploadPhotoResponse();
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );
    final UploadRecordPhotoResult result = await service.uploadPhoto(
      requestId: 'request-upload',
      clientVersion: 'v0.13.2',
      idToken: 'test-id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      takenAt: DateTime.parse('2026-07-29T15:00:00+09:00'),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      locationSource: 'gps',
      displayOrder: 1,
      recordPreparation: RecordPreparationPayload(
        requestId: 'request-record',
        buildingMode: 'new',
        buildingId: 'building-1',
        visitId: 'visit-1',
        buildingName: '第一ビル',
        designTagIds: const <String>['tag-design-1'],
        salesTagIds: const <String>[],
        constructionTagIds: const <String>['tag-construction-1'],
        visitedAt: DateTime.parse('2026-07-29T15:00:00+09:00'),
        triggerTagIds: const <String>['tag-trigger-1'],
        impression: '印象的だった。',
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyM: 8.4,
        locationSource: 'gps',
        expectedPhotoCount: 1,
      ),
      finalizeAfterUpload: true,
    );
    expect(sentBody['action'], 'uploadPhoto');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['base64Data'], base64Encode(<int>[1, 2, 3]));
    expect(payload['latitude'], 35.681236);
    expect(payload['finalizeAfterUpload'], isTrue);
    expect(payload.containsKey('thumbnailBase64Data'), isFalse);
    final Map<String, dynamic> recordDraft =
        payload['recordDraft'] as Map<String, dynamic>;
    expect(recordDraft['requestId'], 'request-record');
    expect(recordDraft['buildingName'], '第一ビル');
    expect(recordDraft['expectedPhotoCount'], 1);
    expect(result.storageFileId, 'drive-file-1');
    expect(result.recordPrepared, isTrue);
    expect(result.recordCompleted, isTrue);
    expect(result.photoCount, 1);
    expect(result.performance?.authenticationMode, 'cache');
    expect(result.performance?.driveSaveMs, 300);
    expect(result.performance?.clientRequestMs, greaterThanOrEqualTo(0));
    service.close();
  });

  test('元写真保存後にサムネイルを別通信で後送信する', () async {
    final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
    final Completer<void> deferredRequestSeen = Completer<void>();
    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      if (body['action'] == 'uploadPhotoThumbnail') {
        if (!deferredRequestSeen.isCompleted) {
          deferredRequestSeen.complete();
        }
        return _jsonResponse(<String, dynamic>{
          'ok': true,
          'requestId': body['requestId'],
          'serverTime': '2026-08-17T16:00:00+09:00',
          'data': <String, dynamic>{
            'photoId': 'photo-1',
            'thumbnailFileId': 'thumbnail-file-1',
            'reused': false,
          },
          'errorCode': null,
          'message': null,
        });
      }
      return _uploadPhotoResponse();
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
          thumbnailService: const _FakeThumbnailService(),
          deferredThumbnailQuietDelay: Duration.zero,
        );

    await service.uploadPhoto(
      requestId: 'request-upload',
      clientVersion: 'v0.19.4',
      idToken: 'test-id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      takenAt: DateTime.parse('2026-08-17T15:00:00+09:00'),
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      locationSource: 'gps',
      displayOrder: 1,
    );

    await deferredRequestSeen.future.timeout(const Duration(seconds: 1));

    expect(requests.length, 2);
    expect(requests.first['action'], 'uploadPhoto');
    final Map<String, dynamic> primaryPayload =
        requests.first['payload'] as Map<String, dynamic>;
    expect(primaryPayload.containsKey('thumbnailBase64Data'), isFalse);

    expect(requests.last['action'], 'uploadPhotoThumbnail');
    final Map<String, dynamic> thumbnailPayload =
        requests.last['payload'] as Map<String, dynamic>;
    expect(thumbnailPayload['buildingId'], 'building-1');
    expect(thumbnailPayload['visitId'], 'visit-1');
    expect(thumbnailPayload['photoId'], 'photo-1');
    expect(thumbnailPayload['thumbnailMimeType'], 'image/jpeg');
    expect(thumbnailPayload['thumbnailByteSize'], 3);
    expect(
      thumbnailPayload['thumbnailBase64Data'],
      base64Encode(<int>[9, 8, 7]),
    );
    service.close();
  });

  test('finalizeRecordで保存完了を確定する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-finalize',
        'serverTime': '2026-07-29T16:00:00+09:00',
        'data': <String, dynamic>{
          'buildingId': 'building-1',
          'visitId': 'visit-1',
          'photoCount': 2,
          'status': 'completed',
          'reused': false,
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );
    final FinalizeRecordResult result = await service.finalizeRecord(
      requestId: 'request-finalize',
      clientVersion: 'v0.13.2',
      idToken: 'test-id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
    );

    expect(sentBody['action'], 'finalizeRecord');
    expect(result.status, 'completed');
    service.close();
  });
}

class _FakeThumbnailService implements RecordThumbnailService {
  const _FakeThumbnailService();

  @override
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes) async {
    return RecordThumbnailData(
      bytes: Uint8List.fromList(<int>[9, 8, 7]),
      mimeType: 'image/jpeg',
      width: 10,
      height: 10,
    );
  }
}

http.Response _uploadPhotoResponse() {
  return _jsonResponse(<String, dynamic>{
    'ok': true,
    'requestId': 'request-upload',
    'serverTime': '2026-07-29T16:00:00+09:00',
    'data': <String, dynamic>{
      'photoId': 'photo-1',
      'storageFileId': 'drive-file-1',
      'byteSize': 3,
      'displayOrder': 1,
      'reused': false,
      'buildingId': 'building-1',
      'visitId': 'visit-1',
      'recordPrepared': true,
      'buildingCreated': true,
      'visitCreated': true,
      'recordCompleted': true,
      'photoCount': 1,
      'saveMode': 'combined_photo_step',
      'performance': <String, dynamic>{
        'authenticationMode': 'cache',
        'authenticationMs': 3,
        'lockWaitMs': 0,
        'lookupMs': 11,
        'base64DecodeMs': 2,
        'driveSaveMs': 300,
        'sheetWriteMs': 40,
        'draftPreparationMs': 120,
        'finalizeMs': 80,
        'handlerTotalMs': 370,
      },
    },
    'errorCode': null,
    'message': null,
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
