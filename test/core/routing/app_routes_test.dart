import 'package:building_record_app/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildingIdから建物詳細URLを作成できる', () {
    expect(
      AppRoutes.buildingDetail('building-12345678'),
      '/browse/building/building-12345678',
    );
    expect(AppRoutes.buildingDetailPattern, '/browse/building/:buildingId');
  });
}
