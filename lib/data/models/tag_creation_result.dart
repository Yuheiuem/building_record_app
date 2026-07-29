import 'package:flutter/foundation.dart';

import 'building_tag.dart';

@immutable
class TagCreationResult {
  const TagCreationResult({
    required this.tag,
    required this.created,
    required this.reactivated,
  });

  factory TagCreationResult.fromJson(Map<String, dynamic> json) {
    final Object? rawTag = json['tag'];
    if (rawTag is! Map<String, dynamic>) {
      throw const FormatException('tagがJSONオブジェクトではありません。');
    }

    return TagCreationResult(
      tag: BuildingTag.fromJson(rawTag),
      created: json['created'] == true,
      reactivated: json['reactivated'] == true,
    );
  }

  final BuildingTag tag;
  final bool created;
  final bool reactivated;
}
