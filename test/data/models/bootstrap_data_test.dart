import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getBootstrapDataのタグ4種類をモデルへ変換できる', () {
    final BootstrapData data = BootstrapData.fromJson(<String, dynamic>{
      'ok': true,
      'requestId': 'request-123',
      'serverTime': '2026-07-28T12:00:00+09:00',
      'data': <String, dynamic>{
        'schemaVersion': '1.0',
        'stage': '2-2',
        'buildings': <Object?>[],
        'tags': <Map<String, dynamic>>[
          _tagJson('trigger-1', 'trigger', '営業の仕事', 10),
          _tagJson('design-1', 'design', '第1設計部', 10),
          _tagJson('sales-1', 'sales', '第1営業部', 10),
          _tagJson('construction-1', 'construction', '当社施工', 10),
        ],
        'counts': <String, dynamic>{
          'buildings': 0,
          'visits': 0,
          'photos': 0,
          'tags': 4,
        },
      },
      'errorCode': null,
      'message': null,
    });

    expect(data.schemaVersion, '1.0');
    expect(data.stage, '2-2');
    expect(data.tags, hasLength(4));
    expect(data.tags.map((BuildingTag tag) => tag.tagType), <BuildingTagType>[
      BuildingTagType.trigger,
      BuildingTagType.design,
      BuildingTagType.sales,
      BuildingTagType.construction,
    ]);
    expect(BuildingTagType.trigger.displayName, 'きっかけ');
    expect(BuildingTagType.design.scopeLabel, '建物ごとに保存');
    expect(data.counts.tags, 4);
  });

  test('未対応のtagTypeはFormatExceptionになる', () {
    expect(
      () => BootstrapData.fromJson(<String, dynamic>{
        'ok': true,
        'serverTime': '2026-07-28T12:00:00+09:00',
        'data': <String, dynamic>{
          'schemaVersion': '1.0',
          'stage': '2-2',
          'buildings': <Object?>[],
          'tags': <Map<String, dynamic>>[
            _tagJson('unknown-1', 'unknown', '不明', 10),
          ],
          'counts': <String, dynamic>{
            'buildings': 0,
            'visits': 0,
            'photos': 0,
            'tags': 1,
          },
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _tagJson(
  String tagId,
  String tagType,
  String tagName,
  int displayOrder,
) {
  return <String, dynamic>{
    'tagId': tagId,
    'tagType': tagType,
    'tagName': tagName,
    'normalizedName': tagName,
    'displayOrder': displayOrder,
    'isActive': true,
    'createdAt': '2026-07-28T10:00:00+09:00',
    'updatedAt': '2026-07-28T10:00:00+09:00',
  };
}
