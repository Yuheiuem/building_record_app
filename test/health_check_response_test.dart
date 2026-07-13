import 'package:building_record_app/data/models/health_check_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apps ScriptのhealthCheck JSONを変換できる', () {
    final HealthCheckResponse response = HealthCheckResponse.fromJson(
      <String, dynamic>{
        'ok': true,
        'requestId': 'request-123',
        'serverTime': '2026-07-13T13:24:34+09:00',
        'data': <String, dynamic>{
          'status': 'ok',
          'stage': '0-3C-1',
          'method': 'POST',
        },
        'errorCode': null,
        'message': null,
      },
    );

    expect(response.ok, isTrue);
    expect(response.isHealthy, isTrue);
    expect(response.requestId, 'request-123');
    expect(response.serverTime, '2026-07-13T13:24:34+09:00');
    expect(response.status, 'ok');
    expect(response.stage, '0-3C-1');
    expect(response.method, 'POST');
    expect(response.errorCode, isNull);
    expect(response.message, isNull);
  });
}
