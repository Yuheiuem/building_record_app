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
  test('同時に送信可能になった2枚はuploadPhotosBatchの1通信へまとめる', () async {
    final List<Map<String, dynamic>> requestBodies = <Map<String, dynamic>>[];
    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      requestBodies.add(body);
      final List<dynamic> photos =
          (body['payload'] as Map<String, dynamic>)['photos'] as List<dynamic>;

      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'requestId': body['requestId'],
          'data': <String, Object?>{
            'results': photos
                .map((dynamic rawItem) {
                  final Map<String, dynamic> item =
                      rawItem as Map<String, dynamic>;
                  final Map<String, dynamic> payload =
                      item['payload'] as Map<String, dynamic>;
                  return <String, Object?>{
                    'requestId': item['requestId'],
                    'photoId': payload['photoId'],
                    'ok': true,
                    'data': _photoResult(
                      photoId: payload['photoId'] as String,
                      byteSize: payload['byteSize'] as int,
                      displayOrder: payload['displayOrder'] as int,
                    ),
                    'errorCode': null,
                    'message': null,
                  };
                })
                .toList(growable: false),
            'batchSize': photos.length,
            'stage': '5-4A.12',
          },
          'errorCode': null,
          'message': null,
        }),
        200,
      );
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.test/exec'),
          thumbnailService: const _NullThumbnailService(),
          deferredThumbnailQuietDelay: Duration.zero,
        );

    final Future<UploadRecordPhotoResult> first = service.uploadPhoto(
      requestId: 'request-a',
      clientVersion: 'v0.19.12',
      idToken: 'token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-a',
      fileName: 'a.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      takenAt: DateTime.utc(2026, 8, 19, 1),
      latitude: 35.0,
      longitude: 139.0,
      accuracyM: 5.0,
      locationSource: 'gps',
      displayOrder: 0,
    );
    final Future<UploadRecordPhotoResult> second = service.uploadPhoto(
      requestId: 'request-b',
      clientVersion: 'v0.19.12',
      idToken: 'token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-b',
      fileName: 'b.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
      takenAt: DateTime.utc(2026, 8, 19, 1, 1),
      latitude: 35.0,
      longitude: 139.0,
      accuracyM: 5.0,
      locationSource: 'gps',
      displayOrder: 1,
    );

    final List<UploadRecordPhotoResult> results =
        await Future.wait<UploadRecordPhotoResult>(
          <Future<UploadRecordPhotoResult>>[first, second],
        );

    expect(results, hasLength(2));
    expect(requestBodies, hasLength(1));
    expect(requestBodies.single['action'], 'uploadPhotosBatch');
    final List<dynamic> sentPhotos =
        (requestBodies.single['payload'] as Map<String, dynamic>)['photos']
            as List<dynamic>;
    expect(sentPhotos, hasLength(2));
    expect(
      sentPhotos.map(
        (dynamic item) => (item as Map<String, dynamic>)['requestId'],
      ),
      <String>['request-a', 'request-b'],
    );

    service.close();
  });

  test('4枚同時要求は2枚バッチ2本を時間差付きで最大2本並行送信する', () async {
    final List<Map<String, dynamic>> requestBodies = <Map<String, dynamic>>[];
    final List<DateTime> requestStartedAt = <DateTime>[];
    final Completer<void> bothBatchRequestsStarted = Completer<void>();
    int activeBatchRequests = 0;
    int maxActiveBatchRequests = 0;

    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      requestBodies.add(body);
      requestStartedAt.add(DateTime.now());
      expect(body['action'], 'uploadPhotosBatch');
      activeBatchRequests += 1;
      if (activeBatchRequests > maxActiveBatchRequests) {
        maxActiveBatchRequests = activeBatchRequests;
      }
      if (requestBodies.length == 2 && !bothBatchRequestsStarted.isCompleted) {
        bothBatchRequestsStarted.complete();
      }

      await bothBatchRequestsStarted.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final List<dynamic> photos =
          (body['payload'] as Map<String, dynamic>)['photos'] as List<dynamic>;
      activeBatchRequests -= 1;
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'requestId': body['requestId'],
          'data': <String, Object?>{
            'results': photos
                .map((dynamic rawItem) {
                  final Map<String, dynamic> item =
                      rawItem as Map<String, dynamic>;
                  final Map<String, dynamic> payload =
                      item['payload'] as Map<String, dynamic>;
                  return <String, Object?>{
                    'requestId': item['requestId'],
                    'photoId': payload['photoId'],
                    'ok': true,
                    'data': _photoResult(
                      photoId: payload['photoId'] as String,
                      byteSize: payload['byteSize'] as int,
                      displayOrder: payload['displayOrder'] as int,
                    ),
                    'errorCode': null,
                    'message': null,
                  };
                })
                .toList(growable: false),
            'batchSize': photos.length,
            'stage': '5-4A.12',
          },
          'errorCode': null,
          'message': null,
        }),
        200,
      );
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.test/exec'),
          thumbnailService: const _NullThumbnailService(),
          deferredThumbnailQuietDelay: Duration.zero,
          parallelBatchStartDelay: const Duration(milliseconds: 50),
        );

    final List<Future<UploadRecordPhotoResult>> futures =
        List<Future<UploadRecordPhotoResult>>.generate(4, (int index) {
          return service.uploadPhoto(
            requestId: 'request-$index',
            clientVersion: 'v0.19.12',
            idToken: 'token',
            buildingId: 'building-1',
            visitId: 'visit-1',
            photoId: 'photo-$index',
            fileName: '$index.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList(<int>[index + 1]),
            takenAt: DateTime.utc(2026, 8, 19, 3, index),
            latitude: 35.0,
            longitude: 139.0,
            accuracyM: 5.0,
            locationSource: 'gps',
            displayOrder: index,
          );
        });

    final List<UploadRecordPhotoResult> results =
        await Future.wait<UploadRecordPhotoResult>(futures);

    expect(results, hasLength(4));
    expect(requestBodies, hasLength(2));
    expect(maxActiveBatchRequests, 2);
    expect(requestStartedAt, hasLength(2));
    final Duration startGap = requestStartedAt[1].difference(
      requestStartedAt[0],
    );
    expect(startGap, greaterThanOrEqualTo(const Duration(milliseconds: 40)));
    for (final Map<String, dynamic> body in requestBodies) {
      final List<dynamic> photos =
          (body['payload'] as Map<String, dynamic>)['photos'] as List<dynamic>;
      expect(photos, hasLength(2));
    }

    service.close();
  });

  test('2枚バッチの片方が失敗しても成功側の結果は受け取れる', () async {
    final MockClient client = MockClient((http.Request request) async {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      final List<dynamic> photos =
          (body['payload'] as Map<String, dynamic>)['photos'] as List<dynamic>;
      final Map<String, dynamic> firstItem = photos[0] as Map<String, dynamic>;
      final Map<String, dynamic> firstPayload =
          firstItem['payload'] as Map<String, dynamic>;
      final Map<String, dynamic> secondItem = photos[1] as Map<String, dynamic>;
      final Map<String, dynamic> secondPayload =
          secondItem['payload'] as Map<String, dynamic>;

      return http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'ok': true,
            'requestId': body['requestId'],
            'data': <String, Object?>{
              'results': <Object?>[
                <String, Object?>{
                  'requestId': firstItem['requestId'],
                  'photoId': firstPayload['photoId'],
                  'ok': true,
                  'data': _photoResult(
                    photoId: firstPayload['photoId'] as String,
                    byteSize: firstPayload['byteSize'] as int,
                    displayOrder: firstPayload['displayOrder'] as int,
                  ),
                },
                <String, Object?>{
                  'requestId': secondItem['requestId'],
                  'photoId': secondPayload['photoId'],
                  'ok': false,
                  'errorCode': 'INTERNAL_ERROR',
                  'message': 'テスト用失敗',
                },
              ],
              'batchSize': 2,
              'stage': '5-4A.12',
            },
            'errorCode': null,
            'message': null,
          }),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final HttpRecordSubmissionApiService service =
        HttpRecordSubmissionApiService(
          client: client,
          endpoint: Uri.parse('https://example.test/exec'),
          thumbnailService: const _NullThumbnailService(),
          deferredThumbnailQuietDelay: Duration.zero,
        );

    final Future<UploadRecordPhotoResult> successFuture = service.uploadPhoto(
      requestId: 'request-success',
      clientVersion: 'v0.19.12',
      idToken: 'token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-success',
      fileName: 'success.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1]),
      takenAt: DateTime.utc(2026, 8, 19, 2),
      latitude: 35.0,
      longitude: 139.0,
      accuracyM: null,
      locationSource: 'manual',
      displayOrder: 0,
    );
    final Future<UploadRecordPhotoResult> failureFuture = service.uploadPhoto(
      requestId: 'request-failure',
      clientVersion: 'v0.19.12',
      idToken: 'token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      photoId: 'photo-failure',
      fileName: 'failure.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[2]),
      takenAt: DateTime.utc(2026, 8, 19, 2, 1),
      latitude: 35.0,
      longitude: 139.0,
      accuracyM: null,
      locationSource: 'manual',
      displayOrder: 1,
    );
    final Future<void> failureExpectation = expectLater(
      failureFuture,
      throwsA(
        isA<RecordSubmissionApiException>()
            .having(
              (RecordSubmissionApiException error) => error.errorCode,
              'errorCode',
              'INTERNAL_ERROR',
            )
            .having(
              (RecordSubmissionApiException error) => error.message,
              'message',
              'テスト用失敗',
            ),
      ),
    );

    final UploadRecordPhotoResult success = await successFuture;
    expect(success.photoId, 'photo-success');
    await failureExpectation;

    service.close();
  });
}

Map<String, Object?> _photoResult({
  required String photoId,
  required int byteSize,
  required int displayOrder,
}) {
  return <String, Object?>{
    'photoId': photoId,
    'storageFileId': 'file-$photoId',
    'byteSize': byteSize,
    'displayOrder': displayOrder,
    'reused': false,
    'buildingId': 'building-1',
    'visitId': 'visit-1',
    'recordPrepared': false,
    'recordCompleted': false,
    'saveMode': 'parallel_step',
    'performance': <String, Object?>{
      'authenticationMode': 'cache',
      'authenticationMs': 1,
      'lockWaitMs': 0,
      'lookupMs': 1,
      'base64DecodeMs': 1,
      'driveSaveMs': 1,
      'sheetWriteMs': 1,
      'handlerTotalMs': 5,
    },
  };
}

class _NullThumbnailService implements RecordThumbnailService {
  const _NullThumbnailService();

  @override
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes) async {
    return null;
  }
}
