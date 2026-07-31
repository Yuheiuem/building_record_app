import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('建物詳細・訪問・写真・タグをJSONから変換できる', () {
    final BuildingDetailData data = BuildingDetailData.fromJson(
      _detailResponse(),
    );

    expect(data.stage, '4-2');
    expect(data.building.buildingName, 'テスト建物');
    expect(data.visits, hasLength(1));
    expect(data.visits.single.impression, '外観を見学した。');
    expect(data.photos, hasLength(1));
    expect(data.photos.single.photoId, 'photo-12345678');
    expect(data.tags, hasLength(2));
    expect(data.counts.visits, 1);
    expect(data.counts.photos, 1);
    expect(data.photosForVisit('visit-12345678'), hasLength(1));
  });

  test('認証付き写真のBase64をバイト列へ変換できる', () {
    final BuildingPhotoData data = BuildingPhotoData.fromJson(<String, dynamic>{
      'ok': true,
      'requestId': 'request-photo',
      'serverTime': '2026-07-30T15:30:00+09:00',
      'data': <String, dynamic>{
        'photoId': 'photo-12345678',
        'fileName': 'photo-12345678.jpg',
        'mimeType': 'image/jpeg',
        'byteSize': 3,
        'base64Data': 'AQID',
        'stage': '4-2',
      },
      'errorCode': null,
      'message': null,
    });

    expect(data.photoId, 'photo-12345678');
    expect(data.bytes, <int>[1, 2, 3]);
  });

  test('画像サイズが一致しない応答はFormatExceptionになる', () {
    expect(
      () => BuildingPhotoData.fromJson(<String, dynamic>{
        'ok': true,
        'serverTime': '2026-07-30T15:30:00+09:00',
        'data': <String, dynamic>{
          'photoId': 'photo-12345678',
          'fileName': 'photo-12345678.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': 4,
          'base64Data': 'AQID',
          'stage': '4-2',
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _detailResponse() {
  return <String, dynamic>{
    'ok': true,
    'requestId': 'request-detail',
    'serverTime': '2026-07-30T15:30:00+09:00',
    'data': <String, dynamic>{
      'schemaVersion': '1.0',
      'stage': '4-2',
      'building': <String, dynamic>{
        'buildingId': 'building-12345678',
        'buildingName': 'テスト建物',
        'searchName': 'てすとたてもの',
        'latitude': 35.6812,
        'longitude': 139.7671,
        'address': '東京都千代田区',
        'designTags': <String>['tag-design-1234'],
        'salesTags': <String>[],
        'constructionTags': <String>['tag-construction-1234'],
        'driveFolderId': null,
        'coverPhotoId': 'photo-12345678',
        'createdAt': '2026-07-30T10:00:00+09:00',
        'updatedAt': '2026-07-30T12:00:00+09:00',
        'isDeleted': false,
      },
      'visits': <Map<String, dynamic>>[
        <String, dynamic>{
          'visitId': 'visit-12345678',
          'buildingId': 'building-12345678',
          'visitedAt': '2026-07-30T14:00:00+09:00',
          'triggerTags': <String>['tag-trigger-1234'],
          'impression': '外観を見学した。',
          'latitude': 35.6813,
          'longitude': 139.7672,
          'accuracyM': 8.5,
          'locationSource': 'gps',
          'status': 'completed',
          'expectedPhotoCount': 1,
          'createdAt': '2026-07-30T14:00:00+09:00',
          'updatedAt': '2026-07-30T14:01:00+09:00',
        },
      ],
      'photos': <Map<String, dynamic>>[
        <String, dynamic>{
          'photoId': 'photo-12345678',
          'buildingId': 'building-12345678',
          'visitId': 'visit-12345678',
          'fileName': 'photo-12345678.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': 12345,
          'width': 1600,
          'height': 1200,
          'takenAt': '2026-07-30T14:00:00+09:00',
          'latitude': 35.6813,
          'longitude': 139.7672,
          'accuracyM': 8.5,
          'locationSource': 'gps',
          'displayOrder': 1,
          'createdAt': '2026-07-30T14:01:00+09:00',
        },
      ],
      'tags': <Map<String, dynamic>>[
        <String, dynamic>{
          'tagId': 'tag-design-1234',
          'tagType': 'design',
          'tagName': '設計第一部',
          'normalizedName': '設計第一部',
          'displayOrder': 10,
          'isActive': true,
          'createdAt': null,
          'updatedAt': null,
        },
        <String, dynamic>{
          'tagId': 'tag-trigger-1234',
          'tagType': 'trigger',
          'tagName': '設計研修',
          'normalizedName': '設計研修',
          'displayOrder': 10,
          'isActive': false,
          'createdAt': null,
          'updatedAt': null,
        },
      ],
      'counts': <String, dynamic>{'visits': 1, 'photos': 1},
    },
    'errorCode': null,
    'message': null,
  };
}
