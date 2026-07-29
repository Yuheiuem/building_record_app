import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('位置情報の取得元をAPI値と表示名へ変換できる', () {
    expect(RecordLocationSource.gps.apiValue, 'gps');
    expect(RecordLocationSource.gps.displayName, '端末の現在地');
    expect(RecordLocationSource.buildingFallback.apiValue, 'building_fallback');
    expect(RecordLocationSource.buildingFallback.displayName, '建物の代表位置');
    expect(RecordLocationSource.manual.apiValue, 'manual');
  });
}
