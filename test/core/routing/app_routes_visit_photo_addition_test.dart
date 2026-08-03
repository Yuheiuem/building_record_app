import 'package:building_record_app/core/routing/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('建物IDと訪問IDから写真追加URLを作成できる', () {
    expect(
      AppRoutes.addPhotosToVisit('building-1', 'visit-1'),
      '/browse/building/building-1/visit/visit-1/photos/add',
    );
  });
}
