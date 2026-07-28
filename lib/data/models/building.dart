import 'package:flutter/foundation.dart';

@immutable
class Building {
  const Building({
    required this.buildingId,
    required this.buildingName,
    required this.searchName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.designTags,
    required this.salesTags,
    required this.constructionTags,
    required this.driveFolderId,
    required this.coverPhotoId,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      buildingId: _requiredString(json['buildingId'], 'buildingId'),
      buildingName: _requiredString(json['buildingName'], 'buildingName'),
      searchName: _optionalString(json['searchName']) ?? '',
      latitude: _optionalDouble(json['latitude'], 'latitude'),
      longitude: _optionalDouble(json['longitude'], 'longitude'),
      address: _optionalString(json['address']),
      designTags: _stringList(json['designTags'], 'designTags'),
      salesTags: _stringList(json['salesTags'], 'salesTags'),
      constructionTags: _stringList(
        json['constructionTags'],
        'constructionTags',
      ),
      driveFolderId: _optionalString(json['driveFolderId']),
      coverPhotoId: _optionalString(json['coverPhotoId']),
      createdAt: _optionalDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt'], 'updatedAt'),
      isDeleted: json['isDeleted'] == true,
    );
  }

  final String buildingId;
  final String buildingName;
  final String searchName;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> designTags;
  final List<String> salesTags;
  final List<String> constructionTags;
  final String? driveFolderId;
  final String? coverPhotoId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
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

double? _optionalDouble(Object? value, String fieldName) {
  if (value == null) {
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
