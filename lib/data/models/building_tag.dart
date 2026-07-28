import 'package:flutter/foundation.dart';

@immutable
class BuildingTag {
  const BuildingTag({
    required this.tagId,
    required this.tagType,
    required this.tagName,
    required this.normalizedName,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuildingTag.fromJson(Map<String, dynamic> json) {
    return BuildingTag(
      tagId: _requiredString(json['tagId'], 'tagId'),
      tagType: _requiredString(json['tagType'], 'tagType'),
      tagName: _requiredString(json['tagName'], 'tagName'),
      normalizedName: _optionalString(json['normalizedName']) ?? '',
      displayOrder: _requiredInt(json['displayOrder'], 'displayOrder'),
      isActive: json['isActive'] == true,
      createdAt: _optionalDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt'], 'updatedAt'),
    );
  }

  final String tagId;
  final String tagType;
  final String tagName;
  final String normalizedName;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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

int _requiredInt(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('$fieldNameが数値ではありません。');
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
