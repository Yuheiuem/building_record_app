import 'dart:convert';

import 'package:building_record_app/data/services/visit_information_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('訪問日時・きっかけ・感想・位置を付けてupdateVisitInformationを送信する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-visit-information',
        'serverTime': '2026-08-04T16:00:00+09:00',
        'data': <String, dynamic>{
          'stage': '5-3B',
          'buildingId': 'building-12345678',
          'visitId': 'visit-12345678',
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpVisitInformationApiService service =
        HttpVisitInformationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );
    final DateTime visitedAt = DateTime.parse('2026-08-04T14:30:00+09:00');

    await service.updateVisitInformation(
      requestId: 'request-visit-information',
      clientVersion: 'v0.18.1',
      idToken: 'test-id-token',
      buildingId: 'building-12345678',
      visitId: 'visit-12345678',
      visitedAt: visitedAt,
      triggerTagIds: const <String>['tag-trigger-1234'],
      impression: '更新後の感想',
      latitude: 35.6812,
      longitude: 139.7671,
      accuracyM: null,
      locationSource: 'manual',
    );

    expect(sentBody['action'], 'updateVisitInformation');
    expect(sentBody['requestId'], 'request-visit-information');
    expect(sentBody['clientVersion'], 'v0.18.1');
    expect(sentBody['idToken'], 'test-id-token');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['buildingId'], 'building-12345678');
    expect(payload['visitId'], 'visit-12345678');
    expect(payload['visitedAt'], visitedAt.toIso8601String());
    expect(payload['triggerTagIds'], <String>['tag-trigger-1234']);
    expect(payload['impression'], '更新後の感想');
    expect(payload['latitude'], 35.6812);
    expect(payload['longitude'], 139.7671);
    expect(payload['accuracyM'], isNull);
    expect(payload['locationSource'], 'manual');

    service.close();
  });

  test('Apps Scriptのエラーを例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _jsonResponse(<String, dynamic>{
        'ok': false,
        'requestId': 'request-visit-information',
        'serverTime': '2026-08-04T16:00:00+09:00',
        'data': null,
        'errorCode': 'VALIDATION_ERROR',
        'message': '訪問日時が正しくありません。',
      });
    });
    final HttpVisitInformationApiService service =
        HttpVisitInformationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await expectLater(
      service.updateVisitInformation(
        requestId: 'request-visit-information',
        clientVersion: 'v0.18.1',
        idToken: 'test-id-token',
        buildingId: 'building-12345678',
        visitId: 'visit-12345678',
        visitedAt: DateTime.parse('2026-08-04T14:30:00+09:00'),
        triggerTagIds: const <String>[],
        impression: '',
        latitude: null,
        longitude: null,
        accuracyM: null,
        locationSource: '',
      ),
      throwsA(
        isA<VisitInformationApiException>()
            .having(
              (VisitInformationApiException error) => error.errorCode,
              'errorCode',
              'VALIDATION_ERROR',
            )
            .having(
              (VisitInformationApiException error) => error.message,
              'message',
              '訪問日時が正しくありません。',
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
