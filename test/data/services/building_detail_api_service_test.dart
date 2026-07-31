import 'dart:convert';

import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('建物IDを付けてgetBuildingDetailを送信する', () async {
    late Map<String, dynamic> sentBody;

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(_detailResponse());
    });
    final HttpBuildingDetailApiService service = HttpBuildingDetailApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final BuildingDetailData result = await service.getBuildingDetail(
      requestId: 'request-detail',
      clientVersion: 'v0.15.0',
      idToken: 'test-id-token',
      buildingId: 'building-12345678',
    );

    expect(sentBody['action'], 'getBuildingDetail');
    expect(sentBody['requestId'], 'request-detail');
    expect(sentBody['clientVersion'], 'v0.15.0');
    expect(sentBody['idToken'], 'test-id-token');
    expect(
      (sentBody['payload'] as Map<String, dynamic>)['buildingId'],
      'building-12345678',
    );
    expect(result.building.buildingName, 'テスト建物');

    service.close();
  });

  test('photoIdを付けてgetPhotoDataを送信する', () async {
    late Map<String, dynamic> sentBody;

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-photo',
        'serverTime': '2026-07-30T15:30:00+09:00',
        'data': <String, dynamic>{
          'photoId': 'photo-12345678',
          'fileName': 'photo-12345678.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': 3,
          'base64Data': 'AQID',
          'stage': '4-2',
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpBuildingDetailApiService service = HttpBuildingDetailApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final BuildingPhotoData result = await service.getPhotoData(
      requestId: 'request-photo',
      clientVersion: 'v0.15.0',
      idToken: 'test-id-token',
      photoId: 'photo-12345678',
    );

    expect(sentBody['action'], 'getPhotoData');
    expect(
      (sentBody['payload'] as Map<String, dynamic>)['photoId'],
      'photo-12345678',
    );
    expect(result.bytes, <int>[1, 2, 3]);

    service.close();
  });

  test('Apps ScriptのNOT_FOUNDを例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _jsonResponse(<String, dynamic>{
        'ok': false,
        'requestId': 'request-detail',
        'serverTime': '2026-07-30T15:30:00+09:00',
        'data': null,
        'errorCode': 'NOT_FOUND',
        'message': '建物が見つかりませんでした。',
      });
    });
    final HttpBuildingDetailApiService service = HttpBuildingDetailApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    await expectLater(
      service.getBuildingDetail(
        requestId: 'request-detail',
        clientVersion: 'v0.15.0',
        idToken: 'test-id-token',
        buildingId: 'building-12345678',
      ),
      throwsA(
        isA<BuildingDetailApiException>()
            .having(
              (BuildingDetailApiException error) => error.errorCode,
              'errorCode',
              'NOT_FOUND',
            )
            .having(
              (BuildingDetailApiException error) => error.message,
              'message',
              '建物が見つかりませんでした。',
            ),
      ),
    );

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

Map<String, dynamic> _detailResponse() {
  return <String, dynamic>{
    'ok': true,
    'requestId': 'request-detail',
    'serverTime': '2026-07-30T15:30:00+09:00',
    'data': <String, dynamic>{
      'schemaVersion': '1.0',
      'stage': '4-2',
      'building': <String, dynamic>{
        'buildingId': 'building-12345678',
        'buildingName': 'テスト建物',
        'searchName': 'てすとたてもの',
        'latitude': 35.6812,
        'longitude': 139.7671,
        'address': '東京都千代田区',
        'designTags': <String>[],
        'salesTags': <String>[],
        'constructionTags': <String>[],
        'driveFolderId': null,
        'coverPhotoId': null,
        'createdAt': null,
        'updatedAt': null,
        'isDeleted': false,
      },
      'visits': <Object?>[],
      'photos': <Object?>[],
      'tags': <Object?>[],
      'counts': <String, dynamic>{'visits': 0, 'photos': 0},
    },
    'errorCode': null,
    'message': null,
  };
}
