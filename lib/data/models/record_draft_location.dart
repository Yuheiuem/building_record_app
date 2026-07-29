import 'package:flutter/foundation.dart';

enum RecordLocationSource { gps, buildingFallback, manual }

extension RecordLocationSourceDetails on RecordLocationSource {
  String get apiValue => switch (this) {
    RecordLocationSource.gps => 'gps',
    RecordLocationSource.buildingFallback => 'building_fallback',
    RecordLocationSource.manual => 'manual',
  };

  String get displayName => switch (this) {
    RecordLocationSource.gps => '端末の現在地',
    RecordLocationSource.buildingFallback => '建物の代表位置',
    RecordLocationSource.manual => '地図で手動指定',
  };
}

@immutable
class RecordDraftLocation {
  const RecordDraftLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.source,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final RecordLocationSource source;
  final DateTime capturedAt;
}
