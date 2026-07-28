import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getBootstrapDataのJSONをモデルへ変換できる', () {
    final BootstrapData data = BootstrapData.fromJson(<String, dynamic>{
      'ok': true,
      'requestId': 'request-123',
      'serverTime': '2026-07-28T12:00:00+09:00',
      'data': <String, dynamic>{
        'schemaVersion': '1.0',
        'stage': '2-1',
        'buildings': <Map<String, dynamic>>[
          <String, dynamic>{
            'buildingId': 'building-1',
            'buildingName': 'テスト建物',
            'searchName': 'てすとたてもの',
            'latitude': 35.6812,
            'longitude': 139.7671,
            'address': '東京都',
            'designTags': <String>['design-1'],
            'salesTags': <String>[],
            'constructionTags': <String>['construction-1'],
            'driveFolderId': null,
            'coverPhotoId': null,
            'createdAt': '2026-07-28T11:00:00+09:00',
            'updatedAt': '2026-07-28T11:30:00+09:00',
            'isDeleted': false,
          },
        ],
        'tags': <Map<String, dynamic>>[
          <String, dynamic>{
            'tagId': 'design-1',
            'tagType': 'design',
            'tagName': '第1設計部',
            'normalizedName': '第1設計部',
            'displayOrder': 10,
            'isActive': true,
            'createdAt': '2026-07-28T10:00:00+09:00',
            'updatedAt': '2026-07-28T10:00:00+09:00',
          },
        ],
        'counts': <String, dynamic>{
          'buildings': 1,
          'visits': 2,
          'photos': 3,
          'tags': 1,
        },
      },
      'errorCode': null,
      'message': null,
    });

    expect(data.requestId, 'request-123');
    expect(data.schemaVersion, '1.0');
    expect(data.stage, '2-1');
    expect(data.buildings, hasLength(1));
    expect(data.buildings.single.buildingName, 'テスト建物');
    expect(data.buildings.single.latitude, 35.6812);
    expect(data.buildings.single.designTags, <String>['design-1']);
    expect(data.tags, hasLength(1));
    expect(data.tags.single.tagType, 'design');
    expect(data.counts.buildings, 1);
    expect(data.counts.visits, 2);
    expect(data.counts.photos, 3);
    expect(data.counts.tags, 1);
  });

  test('dataがない応答はFormatExceptionになる', () {
    expect(
      () => BootstrapData.fromJson(<String, dynamic>{
        'ok': true,
        'serverTime': '2026-07-28T12:00:00+09:00',
        'data': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
