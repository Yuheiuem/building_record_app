import 'dart:convert';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('IDトークン付きgetBootstrapDataをApps Scriptへ送信する', () async {
    late Map<String, dynamic> sentBody;

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;

      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': true,
        'requestId': 'request-123',
        'serverTime': '2026-07-28T12:00:00+09:00',
        'data': <String, dynamic>{
          'schemaVersion': '1.0',
          'stage': '2-2',
          'buildings': <Object?>[],
          'tags': <Object?>[],
          'counts': <String, dynamic>{
            'buildings': 0,
            'visits': 0,
            'photos': 0,
            'tags': 0,
          },
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

    final HttpBootstrapApiService service = HttpBootstrapApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final BootstrapData result = await service.getBootstrapData(
      requestId: 'request-123',
      clientVersion: 'v0.8.0',
      idToken: 'test-id-token',
    );

    expect(sentBody['action'], 'getBootstrapData');
    expect(sentBody['requestId'], 'request-123');
    expect(sentBody['clientVersion'], 'v0.8.0');
    expect(sentBody['idToken'], 'test-id-token');
    expect(sentBody['payload'], isEmpty);
    expect(result.stage, '2-2');

    service.close();
  });

  test('Apps Scriptの失敗応答を例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': false,
        'requestId': 'request-123',
        'serverTime': '2026-07-28T12:00:00+09:00',
        'data': null,
        'errorCode': 'INTERNAL_ERROR',
        'message': 'Spreadsheetが未設定です。',
      });

      return http.Response.bytes(
        utf8.encode(responseBody),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final HttpBootstrapApiService service = HttpBootstrapApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    await expectLater(
      service.getBootstrapData(
        requestId: 'request-123',
        clientVersion: 'v0.8.0',
        idToken: 'test-id-token',
      ),
      throwsA(
        isA<BootstrapApiException>()
            .having(
              (BootstrapApiException error) => error.errorCode,
              'errorCode',
              'INTERNAL_ERROR',
            )
            .having(
              (BootstrapApiException error) => error.message,
              'message',
              'Spreadsheetが未設定です。',
            ),
      ),
    );

    service.close();
  });
}
