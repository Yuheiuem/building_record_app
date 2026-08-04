import 'dart:convert';

import 'package:building_record_app/data/services/building_information_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('建物名・住所・建物タグを付けてupdateBuildingInformationを送信する', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-building-information',
        'serverTime': '2026-08-04T15:00:00+09:00',
        'data': <String, dynamic>{
          'stage': '5-3A',
          'buildingId': 'building-12345678',
          'buildingName': '更新後の建物名',
          'address': '東京都千代田区丸の内1-1',
          'designTagIds': <String>['tag-design-1234'],
          'salesTagIds': <String>['tag-sales-1234'],
          'constructionTagIds': <String>['tag-construction-1234'],
        },
        'errorCode': null,
        'message': null,
      });
    });
    final HttpBuildingInformationApiService service =
        HttpBuildingInformationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await service.updateBuildingInformation(
      requestId: 'request-building-information',
      clientVersion: 'v0.18.0',
      idToken: 'test-id-token',
      buildingId: 'building-12345678',
      buildingName: '更新後の建物名',
      address: '東京都千代田区丸の内1-1',
      designTagIds: const <String>['tag-design-1234'],
      salesTagIds: const <String>['tag-sales-1234'],
      constructionTagIds: const <String>['tag-construction-1234'],
    );

    expect(sentBody['action'], 'updateBuildingInformation');
    expect(sentBody['requestId'], 'request-building-information');
    expect(sentBody['clientVersion'], 'v0.18.0');
    expect(sentBody['idToken'], 'test-id-token');
    final Map<String, dynamic> payload =
        sentBody['payload'] as Map<String, dynamic>;
    expect(payload['buildingId'], 'building-12345678');
    expect(payload['buildingName'], '更新後の建物名');
    expect(payload['address'], '東京都千代田区丸の内1-1');
    expect(payload['designTagIds'], <String>['tag-design-1234']);
    expect(payload['salesTagIds'], <String>['tag-sales-1234']);
    expect(payload['constructionTagIds'], <String>['tag-construction-1234']);

    service.close();
  });

  test('Apps Scriptのエラーを例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _jsonResponse(<String, dynamic>{
        'ok': false,
        'requestId': 'request-building-information',
        'serverTime': '2026-08-04T15:00:00+09:00',
        'data': null,
        'errorCode': 'VALIDATION_ERROR',
        'message': '建物名を入力してください。',
      });
    });
    final HttpBuildingInformationApiService service =
        HttpBuildingInformationApiService(
          client: client,
          endpoint: Uri.parse('https://example.com/exec'),
        );

    await expectLater(
      service.updateBuildingInformation(
        requestId: 'request-building-information',
        clientVersion: 'v0.18.0',
        idToken: 'test-id-token',
        buildingId: 'building-12345678',
        buildingName: '',
        address: null,
        designTagIds: const <String>[],
        salesTagIds: const <String>[],
        constructionTagIds: const <String>[],
      ),
      throwsA(
        isA<BuildingInformationApiException>()
            .having(
              (BuildingInformationApiException error) => error.errorCode,
              'errorCode',
              'VALIDATION_ERROR',
            )
            .having(
              (BuildingInformationApiException error) => error.message,
              'message',
              '建物名を入力してください。',
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
