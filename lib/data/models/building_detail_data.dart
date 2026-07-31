import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'building.dart';
import 'building_tag.dart';

@immutable
class BuildingDetailCounts {
  const BuildingDetailCounts({required this.visits, required this.photos});

  factory BuildingDetailCounts.fromJson(Map<String, dynamic> json) {
    return BuildingDetailCounts(
      visits: _requiredInt(json['visits'], 'counts.visits'),
      photos: _requiredInt(json['photos'], 'counts.photos'),
    );
  }

  final int visits;
  final int photos;
}

@immutable
class BuildingVisit {
  const BuildingVisit({
    required this.visitId,
    required this.buildingId,
    required this.visitedAt,
    required this.triggerTags,
    required this.impression,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationSource,
    required this.status,
    required this.expectedPhotoCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuildingVisit.fromJson(Map<String, dynamic> json) {
    return BuildingVisit(
      visitId: _requiredString(json['visitId'], 'visitId'),
      buildingId: _requiredString(json['buildingId'], 'buildingId'),
      visitedAt: _requiredDateTime(json['visitedAt'], 'visitedAt'),
      triggerTags: _stringList(json['triggerTags'], 'triggerTags'),
      impression: _optionalString(json['impression']) ?? '',
      latitude: _optionalDouble(json['latitude'], 'latitude'),
      longitude: _optionalDouble(json['longitude'], 'longitude'),
      accuracyM: _optionalDouble(json['accuracyM'], 'accuracyM'),
      locationSource: _optionalString(json['locationSource']) ?? '',
      status: _requiredString(json['status'], 'status'),
      expectedPhotoCount: _requiredInt(
        json['expectedPhotoCount'],
        'expectedPhotoCount',
      ),
      createdAt: _optionalDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt'], 'updatedAt'),
    );
  }

  final String visitId;
  final String buildingId;
  final DateTime visitedAt;
  final List<String> triggerTags;
  final String impression;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String locationSource;
  final String status;
  final int expectedPhotoCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
class BuildingPhoto {
  const BuildingPhoto({
    required this.photoId,
    required this.buildingId,
    required this.visitId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.takenAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationSource,
    required this.displayOrder,
    required this.createdAt,
  });

  factory BuildingPhoto.fromJson(Map<String, dynamic> json) {
    return BuildingPhoto(
      photoId: _requiredString(json['photoId'], 'photoId'),
      buildingId: _requiredString(json['buildingId'], 'buildingId'),
      visitId: _requiredString(json['visitId'], 'visitId'),
      fileName: _requiredString(json['fileName'], 'fileName'),
      mimeType: _requiredString(json['mimeType'], 'mimeType'),
      byteSize: _requiredInt(json['byteSize'], 'byteSize'),
      width: _optionalInt(json['width'], 'width'),
      height: _optionalInt(json['height'], 'height'),
      takenAt: _optionalDateTime(json['takenAt'], 'takenAt'),
      latitude: _optionalDouble(json['latitude'], 'latitude'),
      longitude: _optionalDouble(json['longitude'], 'longitude'),
      accuracyM: _optionalDouble(json['accuracyM'], 'accuracyM'),
      locationSource: _optionalString(json['locationSource']) ?? '',
      displayOrder: _requiredInt(json['displayOrder'], 'displayOrder'),
      createdAt: _optionalDateTime(json['createdAt'], 'createdAt'),
    );
  }

  final String photoId;
  final String buildingId;
  final String visitId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String locationSource;
  final int displayOrder;
  final DateTime? createdAt;
}

@immutable
class BuildingDetailData {
  const BuildingDetailData({
    required this.requestId,
    required this.serverTime,
    required this.schemaVersion,
    required this.stage,
    required this.building,
    required this.visits,
    required this.photos,
    required this.tags,
    required this.counts,
  });

  factory BuildingDetailData.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw FormatException(
        _optionalString(json['message']) ?? 'API応答が失敗を示しています。',
      );
    }

    final Object? rawData = json['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('dataがJSONオブジェクトではありません。');
    }

    final Object? rawBuilding = rawData['building'];
    final Object? rawVisits = rawData['visits'];
    final Object? rawPhotos = rawData['photos'];
    final Object? rawTags = rawData['tags'];
    final Object? rawCounts = rawData['counts'];

    if (rawBuilding is! Map<String, dynamic>) {
      throw const FormatException('buildingがJSONオブジェクトではありません。');
    }
    if (rawVisits is! List<dynamic>) {
      throw const FormatException('visitsが配列ではありません。');
    }
    if (rawPhotos is! List<dynamic>) {
      throw const FormatException('photosが配列ではありません。');
    }
    if (rawTags is! List<dynamic>) {
      throw const FormatException('tagsが配列ではありません。');
    }
    if (rawCounts is! Map<String, dynamic>) {
      throw const FormatException('countsがJSONオブジェクトではありません。');
    }

    return BuildingDetailData(
      requestId: _optionalString(json['requestId']),
      serverTime: _requiredDateTime(json['serverTime'], 'serverTime'),
      schemaVersion: _requiredString(rawData['schemaVersion'], 'schemaVersion'),
      stage: _requiredString(rawData['stage'], 'stage'),
      building: Building.fromJson(rawBuilding),
      visits: List<BuildingVisit>.unmodifiable(
        rawVisits.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('visits内の要素がJSONではありません。');
          }
          return BuildingVisit.fromJson(item);
        }),
      ),
      photos: List<BuildingPhoto>.unmodifiable(
        rawPhotos.map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('photos内の要素がJSONではありません。');
          }
          return BuildingPhoto.fromJson(item);
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
      counts: BuildingDetailCounts.fromJson(rawCounts),
    );
  }

  final String? requestId;
  final DateTime serverTime;
  final String schemaVersion;
  final String stage;
  final Building building;
  final List<BuildingVisit> visits;
  final List<BuildingPhoto> photos;
  final List<BuildingTag> tags;
  final BuildingDetailCounts counts;

  List<BuildingPhoto> photosForVisit(String visitId) {
    return List<BuildingPhoto>.unmodifiable(
      photos.where((BuildingPhoto photo) => photo.visitId == visitId),
    );
  }
}

@immutable
class BuildingPhotoData {
  const BuildingPhotoData({
    required this.requestId,
    required this.serverTime,
    required this.photoId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.bytes,
    required this.stage,
  });

  factory BuildingPhotoData.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw FormatException(
        _optionalString(json['message']) ?? 'API応答が失敗を示しています。',
      );
    }

    final Object? rawData = json['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('dataがJSONオブジェクトではありません。');
    }

    final String base64Data = _requiredString(
      rawData['base64Data'],
      'base64Data',
    );
    late final Uint8List bytes;
    try {
      bytes = base64Decode(base64Data);
    } on FormatException {
      throw const FormatException('base64Dataが正しいBase64ではありません。');
    }

    final int byteSize = _requiredInt(rawData['byteSize'], 'byteSize');
    if (bytes.length != byteSize) {
      throw const FormatException('画像データのサイズがbyteSizeと一致しません。');
    }

    return BuildingPhotoData(
      requestId: _optionalString(json['requestId']),
      serverTime: _requiredDateTime(json['serverTime'], 'serverTime'),
      photoId: _requiredString(rawData['photoId'], 'photoId'),
      fileName: _requiredString(rawData['fileName'], 'fileName'),
      mimeType: _requiredString(rawData['mimeType'], 'mimeType'),
      byteSize: byteSize,
      bytes: bytes,
      stage: _requiredString(rawData['stage'], 'stage'),
    );
  }

  final String? requestId;
  final DateTime serverTime;
  final String photoId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final Uint8List bytes;
  final String stage;
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

DateTime? _optionalDateTime(Object? value, String fieldName) {
  final String? text = _optionalString(value);
  if (text == null) {
    return null;
  }
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

int? _optionalInt(Object? value, String fieldName) {
  if (value == null || value == '') {
    return null;
  }
  return _requiredInt(value, fieldName);
}

double? _optionalDouble(Object? value, String fieldName) {
  if (value == null || value == '') {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$fieldNameが数値ではありません。');
}

List<String> _stringList(Object? value, String fieldName) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<dynamic>) {
    throw FormatException('$fieldNameが配列ではありません。');
  }
  return List<String>.unmodifiable(
    value.map((dynamic item) {
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('$fieldNameに文字列以外が含まれています。');
      }
      return item.trim();
    }),
  );
}
