import 'package:flutter/foundation.dart';

@immutable
class HealthCheckResponse {
  const HealthCheckResponse({
    required this.ok,
    required this.requestId,
    required this.serverTime,
    required this.status,
    required this.stage,
    required this.method,
    required this.errorCode,
    required this.message,
  });

  factory HealthCheckResponse.fromJson(Map<String, dynamic> json) {
    final Object? rawData = json['data'];
    final Map<String, dynamic>? data = rawData is Map<String, dynamic>
        ? rawData
        : null;

    return HealthCheckResponse(
      ok: json['ok'] == true,
      requestId: _optionalString(json['requestId']),
      serverTime: _optionalString(json['serverTime']),
      status: _optionalString(data?['status']),
      stage: _optionalString(data?['stage']),
      method: _optionalString(data?['method']),
      errorCode: _optionalString(json['errorCode']),
      message: _optionalString(json['message']),
    );
  }

  final bool ok;
  final String? requestId;
  final String? serverTime;
  final String? status;
  final String? stage;
  final String? method;
  final String? errorCode;
  final String? message;

  bool get isHealthy => ok && status == 'ok';

  static String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
