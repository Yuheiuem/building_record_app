import 'dart:convert';

import 'package:building_record_app/data/services/building_location_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('建物IDと代表座標を付けてupdateBuildingLocationを送信する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-location',
        'serverTime': '2026-08-03T14:00:00+09:00',
        'data': <String, dynamic>{
          'stage': '5-1B',
          'buildingId': 'building-12345678',
          'latitude': 35.681236,
          'longitude': 139.767125,
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpBuildingLocationApiService service =
        HttpBuildingLocationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await service.updateBuildingLocation(
      requestId: 'request-location',
      clientVersion: 'v0.16.1',
      idToken: 'test-id-token',
      buildingId: 'building-12345678',
      latitude: 35.681236,
      longitude: 139.767125,
    );

    expect(sentBody['action'], 'updateBuildingLocation');
    expect(sentBody['requestId'], 'request-location');
    expect(sentBody['clientVersion'], 'v0.16.1');
    expect(sentBody['idToken'], 'test-id-token');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['buildingId'], 'building-12345678');
    expect(payload['latitude'], 35.681236);
    expect(payload['longitude'], 139.767125);

    service.close();
  });

  test('Apps Scriptのエラーを例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _jsonResponse(<String, dynamic>{
        'ok': false,
        'requestId': 'request-location',
        'serverTime': '2026-08-03T14:00:00+09:00',
        'data': null,
        'errorCode': 'NOT_FOUND',
        'message': '建物が見つかりませんでした。',
      });
    });
    final HttpBuildingLocationApiService service =
        HttpBuildingLocationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await expectLater(
      service.updateBuildingLocation(
        requestId: 'request-location',
        clientVersion: 'v0.16.1',
        idToken: 'test-id-token',
        buildingId: 'building-12345678',
        latitude: 35.681236,
        longitude: 139.767125,
      ),
      throwsA(
        isA<BuildingLocationApiException>()
            .having(
              (BuildingLocationApiException error) => error.errorCode,
              'errorCode',
              'NOT_FOUND',
            )
            .having(
              (BuildingLocationApiException error) => error.message,
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
