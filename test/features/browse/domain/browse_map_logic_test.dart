import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/features/browse/domain/browse_map_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('地図範囲内の建物だけを北から順に返す', () {
    const BrowseMapBounds bounds = BrowseMapBounds(
      north: 35.8,
      south: 35.5,
      east: 140.0,
      west: 139.5,
    );
    final List<Building> buildings = <Building>[
      _building('south', '南の建物', 35.55, 139.7),
      _building('outside', '範囲外', 36.0, 139.7),
      _building('north', '北の建物', 35.75, 139.7),
      _buildingWithoutCoordinates('missing', '座標なし'),
    ];

    final List<Building> result = visibleBuildings(buildings, bounds);

    expect(result.map((Building building) => building.buildingId), <String>[
      'north',
      'south',
    ]);
  });

  test('同じ緯度なら建物名で並べる', () {
    final List<Building> buildings = <Building>[
      _building('b', '乙ビル', 35.7, 139.7),
      _building('a', '甲ビル', 35.7, 139.8),
    ];

    final List<Building> result = sortBuildingsNorthToSouth(buildings);

    expect(result.map((Building building) => building.buildingName), <String>[
      '乙ビル',
      '甲ビル',
    ]);
  });

  test('地図の縦横が4km未満なら建物名を表示する', () {
    const BrowseMapBounds compactBounds = BrowseMapBounds(
      north: 35.69,
      south: 35.67,
      east: 139.78,
      west: 139.75,
    );
    const BrowseMapBounds wideBounds = BrowseMapBounds(
      north: 35.75,
      south: 35.60,
      east: 139.90,
      west: 139.60,
    );

    expect(shouldShowBuildingLabels(compactBounds), isTrue);
    expect(shouldShowBuildingLabels(wideBounds), isFalse);
  });

  test('建物名・検索名・住所で絞り込める', () {
    final List<Building> buildings = <Building>[
      _building(
        'one',
        '第一ビル',
        35.7,
        139.7,
        searchName: 'だいいちびる',
        address: '東京都千代田区',
      ),
      _building('two', '第二ビル', 35.6, 139.7),
    ];

    expect(filterBuildingsByQuery(buildings, '千代田').length, 1);
    expect(filterBuildingsByQuery(buildings, 'だいいち').length, 1);
    expect(filterBuildingsByQuery(buildings, '第二').length, 1);
  });
}

Building _building(
  String id,
  String name,
  double latitude,
  double longitude, {
  String searchName = '',
  String? address,
}) {
  return Building(
    buildingId: id,
    buildingName: name,
    searchName: searchName,
    latitude: latitude,
    longitude: longitude,
    address: address,
    designTags: const <String>[],
    salesTags: const <String>[],
    constructionTags: const <String>[],
    driveFolderId: null,
    coverPhotoId: null,
    createdAt: null,
    updatedAt: null,
    isDeleted: false,
  );
}

Building _buildingWithoutCoordinates(String id, String name) {
  return Building(
    buildingId: id,
    buildingName: name,
    searchName: '',
    latitude: null,
    longitude: null,
    address: null,
    designTags: const <String>[],
    salesTags: const <String>[],
    constructionTags: const <String>[],
    driveFolderId: null,
    coverPhotoId: null,
    createdAt: null,
    updatedAt: null,
    isDeleted: false,
  );
}
