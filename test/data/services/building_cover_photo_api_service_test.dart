import 'dart:convert';

import 'package:building_record_app/data/services/building_cover_photo_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('代表写真を更新する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-cover-update',
        'serverTime': '2026-08-04T16:30:00+09:00',
        'data': <String, dynamic>{
          'stage': '5-4A',
          'buildingId': 'building-12345678',
          'coverPhotoId': 'photo-12345678',
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpBuildingCoverPhotoApiService service =
        HttpBuildingCoverPhotoApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await service.updateBuildingCoverPhoto(
      requestId: 'request-cover-update',
      clientVersion: 'v0.19.0',
      idToken: 'test-id-token',
      buildingId: 'building-12345678',
      photoId: 'photo-12345678',
    );

    expect(sentBody['action'], 'updateBuildingCoverPhoto');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['buildingId'], 'building-12345678');
    expect(payload['photoId'], 'photo-12345678');

    service.close();
  });

  test('代表写真サムネイルをまとめて取得する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-cover-thumbnails',
        'serverTime': '2026-08-04T16:30:00+09:00',
        'data': <String, dynamic>{
          'stage': '5-4A',
          'thumbnails': <Map<String, dynamic>>[
            <String, dynamic>{
              'photoId': 'photo-12345678',
              'fileName': 'photo-12345678.jpg',
              'mimeType': 'image/jpeg',
              'byteSize': 3,
              'base64Data': base64Encode(<int>[1, 2, 3]),
              'source': 'thumbnail',
            },
          ],
          'missingPhotoIds': <String>[],
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpBuildingCoverPhotoApiService service =
        HttpBuildingCoverPhotoApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    final Map<String, BuildingCoverThumbnailData> result = await service
        .getCoverPhotoThumbnails(
          requestId: 'request-cover-thumbnails',
          clientVersion: 'v0.19.0',
          idToken: 'test-id-token',
          photoIds: const <String>['photo-12345678'],
        );

    expect(sentBody['action'], 'getCoverPhotoThumbnails');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['photoIds'], <String>['photo-12345678']);
    expect(result.keys, <String>['photo-12345678']);
    expect(result['photo-12345678']?.bytes, <int>[1, 2, 3]);

    service.close();
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
