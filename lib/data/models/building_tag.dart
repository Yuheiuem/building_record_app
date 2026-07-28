import 'package:flutter/foundation.dart';

enum BuildingTagType { trigger, design, sales, construction }

extension BuildingTagTypeDetails on BuildingTagType {
  String get apiValue => switch (this) {
    BuildingTagType.trigger => 'trigger',
    BuildingTagType.design => 'design',
    BuildingTagType.sales => 'sales',
    BuildingTagType.construction => 'construction',
  };

  String get displayName => switch (this) {
    BuildingTagType.trigger => 'きっかけ',
    BuildingTagType.design => '設計',
    BuildingTagType.sales => '営業',
    BuildingTagType.construction => '施工',
  };

  String get scopeLabel => switch (this) {
    BuildingTagType.trigger => '訪問ごとに保存',
    BuildingTagType.design => '建物ごとに保存',
    BuildingTagType.sales => '建物ごとに保存',
    BuildingTagType.construction => '建物ごとに保存',
  };
}

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
      tagType: _requiredTagType(json['tagType']),
      tagName: _requiredString(json['tagName'], 'tagName'),
      normalizedName: _optionalString(json['normalizedName']) ?? '',
      displayOrder: _requiredInt(json['displayOrder'], 'displayOrder'),
      isActive: json['isActive'] == true,
      createdAt: _optionalDateTime(json['createdAt'], 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt'], 'updatedAt'),
    );
  }

  final String tagId;
  final BuildingTagType tagType;
  final String tagName;
  final String normalizedName;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

BuildingTagType _requiredTagType(Object? value) {
  final String text = _requiredString(value, 'tagType');

  for (final BuildingTagType type in BuildingTagType.values) {
    if (type.apiValue == text) {
      return type;
    }
  }

  throw FormatException('未対応のtagTypeです: $text');
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
