import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/tag_creation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('タグ追加結果をJSONから変換できる', () {
    final TagCreationResult result = TagCreationResult.fromJson(
      <String, dynamic>{
        'tag': <String, dynamic>{
          'tagId': 'tag-design-1',
          'tagType': 'design',
          'tagName': '設計第一室',
          'normalizedName': '設計第一室',
          'displayOrder': 10,
          'isActive': true,
          'createdAt': '2026-07-29T10:00:00+09:00',
          'updatedAt': '2026-07-29T10:00:00+09:00',
        },
        'created': true,
        'reactivated': false,
      },
    );

    expect(result.tag.tagId, 'tag-design-1');
    expect(result.tag.tagType, BuildingTagType.design);
    expect(result.tag.tagName, '設計第一室');
    expect(result.created, isTrue);
    expect(result.reactivated, isFalse);
  });
}
