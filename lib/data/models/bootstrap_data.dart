import 'package:flutter/foundation.dart';

import 'building.dart';
import 'building_tag.dart';

@immutable
class BootstrapCounts {
  const BootstrapCounts({
    required this.buildings,
    required this.visits,
    required this.photos,
    required this.tags,
  });

  factory BootstrapCounts.fromJson(Map<String, dynamic> json) {
    return BootstrapCounts(
      buildings: _requiredInt(json['buildings'], 'counts.buildings'),
      visits: _requiredInt(json['visits'], 'counts.visits'),
      photos: _requiredInt(json['photos'], 'counts.photos'),
      tags: _requiredInt(json['tags'], 'counts.tags'),
    );
  }

  final int buildings;
  final int visits;
  final int photos;
  final int tags;
}

@immutable
class BootstrapData {
  const BootstrapData({
    required this.requestId,
    required this.serverTime,
    required this.schemaVersion,
    required this.stage,
    required this.buildings,
    required this.tags,
    required this.counts,
  });

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw FormatException(
        _optionalString(json['message']) ?? 'API応答が失敗を示しています。',
      );
    }

    final Object? rawData = json['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('dataがJSONオブジェクトではありません。');
    }

    final Object? rawBuildings = rawData['buildings'];
    final Object? rawTags = rawData['tags'];
    final Object? rawCounts = rawData['counts'];

    if (rawBuildings is! List<dynamic>) {
      throw const FormatException('buildingsが配列ではありません。');
    }
    if (rawTags is! List<dynamic>) {
      throw const FormatException('tagsが配列ではありません。');
    }
    if (rawCounts is! Map<String, dynamic>) {
      throw const FormatException('countsがJSONオブジェクトではありません。');
    }

    return BootstrapData(
      requestId: _optionalString(json['requestId']),
      serverTime: _requiredDateTime(json['serverTime'], 'serverTime'),
      schemaVersion: _requiredString(rawData['schemaVersion'], 'schemaVersion'),
      stage: _requiredString(rawData['stage'], 'stage'),
      buildings: List<Building>.unmodifiable(
        rawBuildings.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('buildings内の要素がJSONではありません。');
          }
          return Building.fromJson(item);
        }),
      ),
      tags: List<BuildingTag>.unmodifiable(
        rawTags.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('tags内の要素がJSONではありません。');
          }
          return BuildingTag.fromJson(item);
        }),
      ),
      counts: BootstrapCounts.fromJson(rawCounts),
    );
  }

  final String? requestId;
  final DateTime serverTime;
  final String schemaVersion;
  final String stage;
  final List<Building> buildings;
  final List<BuildingTag> tags;
  final BootstrapCounts counts;
}

String _requiredString(Object? value, String fieldName) {
  final String? result = _optionalString(value);
  if (result == null) {
    throw FormatException('$fieldNameがありません。');
  }
  return result;
}

String? _optionalString(Object? value) {
  if (value is! String) {
    return null;
  }
  final String result = value.trim();
  return result.isEmpty ? null : result;
}

DateTime _requiredDateTime(Object? value, String fieldName) {
  final String text = _requiredString(value, fieldName);
  final DateTime? result = DateTime.tryParse(text);
  if (result == null) {
    throw FormatException('$fieldNameが日時形式ではありません。');
  }
  return result;
}

int _requiredInt(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$fieldNameが数値ではありません。');
}
