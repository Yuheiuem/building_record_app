import 'dart:convert';

import 'package:building_record_app/data/models/health_check_response.dart';
import 'package:building_record_app/data/services/apps_script_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('healthCheckでIDトークンをApps Scriptへ送信する', () async {
    late Map<String, dynamic> sentBody;

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;

      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': true,
        'requestId': 'request-123',
        'serverTime': '2026-07-13T13:24:34+09:00',
        'data': <String, dynamic>{
          'status': 'ok',
          'stage': '0-3D',
          'method': 'POST',
          'authenticated': true,
          'validationMode': 'tokeninfo_spike',
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

    final HttpAppsScriptApiService service = HttpAppsScriptApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final HealthCheckResponse response = await service.healthCheck(
      requestId: 'request-123',
      clientVersion: 'v0.4.0',
      idToken: 'test-id-token',
    );

    expect(sentBody['action'], 'healthCheck');
    expect(sentBody['requestId'], 'request-123');
    expect(sentBody['clientVersion'], 'v0.4.0');
    expect(sentBody['idToken'], 'test-id-token');
    expect(response.isHealthy, isTrue);

    service.close();
  });

  test('Apps Scriptの認証拒否を例外として扱う', () async {
    final MockClient client = MockClient((http.Request request) async {
      final String responseBody = jsonEncode(<String, dynamic>{
        'ok': false,
        'requestId': 'request-123',
        'serverTime': '2026-07-13T13:24:34+09:00',
        'data': null,
        'errorCode': 'FORBIDDEN',
        'message': 'このGoogleアカウントにはアクセス権限がありません。',
      });

      return http.Response.bytes(
        utf8.encode(responseBody),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final HttpAppsScriptApiService service = HttpAppsScriptApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    await expectLater(
      service.healthCheck(
        requestId: 'request-123',
        clientVersion: 'v0.4.0',
        idToken: 'test-id-token',
      ),
      throwsA(
        isA<AppsScriptApiException>()
            .having(
              (AppsScriptApiException error) => error.errorCode,
              'errorCode',
              'FORBIDDEN',
            )
            .having(
              (AppsScriptApiException error) => error.message,
              'message',
              'このGoogleアカウントにはアクセス権限がありません。',
            ),
      ),
    );

    service.close();
  });
}
