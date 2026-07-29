import 'dart:convert';

import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/tag_creation_result.dart';
import 'package:building_record_app/data/services/tag_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('createTagでタグ種類と名称をApps Scriptへ送信する', () async {
    late Map<String, dynamic> sentBody;

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;

      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': true,
        'requestId': 'request-1',
        'serverTime': '2026-07-29T10:00:00+09:00',
        'data': <String, dynamic>{
          'tag': <String, dynamic>{
            'tagId': 'tag-design-new',
            'tagType': 'design',
            'tagName': '新しい設計室',
            'normalizedName': '新しい設計室',
            'displayOrder': 20,
            'isActive': true,
            'createdAt': '2026-07-29T10:00:00+09:00',
            'updatedAt': '2026-07-29T10:00:00+09:00',
          },
          'created': true,
          'reactivated': false,
        },
        'errorCode': null,
        'message': null,
      });

      return http.Response.bytes(
        utf8.encode(responseBody),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final HttpTagApiService service = HttpTagApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final TagCreationResult result = await service.createTag(
      requestId: 'request-1',
      clientVersion: 'v0.12.0',
      idToken: 'test-id-token',
      tagType: BuildingTagType.design,
      tagName: '新しい設計室',
    );

    expect(sentBody['action'], 'createTag');
    expect(sentBody['requestId'], 'request-1');
    expect(sentBody['idToken'], 'test-id-token');
    expect(sentBody['clientVersion'], 'v0.12.0');
    expect(sentBody['payload'], <String, dynamic>{
      'tagType': 'design',
      'tagName': '新しい設計室',
    });
    expect(result.tag.tagId, 'tag-design-new');
    expect(result.created, isTrue);

    service.close();
  });

  test('Apps Scriptの入力エラーを例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': false,
        'requestId': 'request-2',
        'serverTime': '2026-07-29T10:00:00+09:00',
        'data': null,
        'errorCode': 'VALIDATION_ERROR',
        'message': 'タグ名を入力してください。',
      });

      return http.Response.bytes(
        utf8.encode(responseBody),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final HttpTagApiService service = HttpTagApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    await expectLater(
      service.createTag(
        requestId: 'request-2',
        clientVersion: 'v0.12.0',
        idToken: 'test-id-token',
        tagType: BuildingTagType.trigger,
        tagName: '',
      ),
      throwsA(
        isA<TagApiException>()
            .having(
              (TagApiException error) => error.errorCode,
              'errorCode',
              'VALIDATION_ERROR',
            )
            .having(
              (TagApiException error) => error.message,
              'message',
              'タグ名を入力してください。',
            ),
      ),
    );

    service.close();
  });
}
