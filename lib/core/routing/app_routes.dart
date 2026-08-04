abstract final class AppRoutes {
  static const String loading = '/loading';
  static const String signIn = '/sign-in';
  static const String home = '/';
  static const String record = '/record';
  static const String browse = '/browse';
  static const String buildingDetailPattern = '/browse/building/:buildingId';
  static const String visitPhotoAdditionPattern =
      '/browse/building/:buildingId/visit/:visitId/photos/add';
  static const String diagnostics = '/diagnostics';

  static String recordForBuilding(String buildingId) {
    return Uri(
      path: record,
      queryParameters: <String, String>{'buildingId': buildingId},
    ).toString();
  }

  static String buildingDetail(String buildingId) {
    return '/browse/building/${Uri.encodeComponent(buildingId)}';
  }

  static String addPhotosToVisit(String buildingId, String visitId) {
    return '/browse/building/${Uri.encodeComponent(buildingId)}'
        '/visit/${Uri.encodeComponent(visitId)}/photos/add';
  }
}
