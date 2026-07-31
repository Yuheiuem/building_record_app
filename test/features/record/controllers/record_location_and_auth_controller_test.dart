import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/data/services/tag_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('地図で選んだ座標をmanualとして保持する', () {
    final _RefreshableAuthService authService = _RefreshableAuthService();
    final RecordDraftController controller = _createController(
      authService: authService,
      bootstrapApiService: _ExpiringBootstrapApiService(),
    );

    controller.useManualLocation(latitude: 35.658581, longitude: 139.745433);

    expect(controller.visitLocation?.latitude, 35.658581);
    expect(controller.visitLocation?.longitude, 139.745433);
    expect(controller.visitLocation?.accuracyM, isNull);
    expect(controller.visitLocation?.source, RecordLocationSource.manual);
    expect(controller.locationNoticeMessage, '地図で指定した位置を使用します。');

    controller.dispose();
  });

  test('AUTH_REQUIRED時にIDトークンを更新して候補データを再取得する', () async {
    final _RefreshableAuthService authService = _RefreshableAuthService();
    final _ExpiringBootstrapApiService bootstrapApiService =
        _ExpiringBootstrapApiService();
    final RecordDraftController controller = _createController(
      authService: authService,
      bootstrapApiService: bootstrapApiService,
    );

    await controller.loadBootstrapData();
    await Future<void>.delayed(Duration.zero);

    expect(authService.refreshCallCount, 1);
    expect(bootstrapApiService.receivedTokens, <String>['expired', 'fresh']);
    expect(controller.requiresReauthentication, isFalse);
    expect(controller.hasLoadedBootstrap, isTrue);
    expect(controller.bootstrapErrorMessage, isNull);

    controller.dispose();
  });
}

RecordDraftController _createController({
  required _RefreshableAuthService authService,
  required BootstrapApiService bootstrapApiService,
}) {
  return RecordDraftController(
    imagePickerService: _EmptyImagePickerService(),
    bootstrapApiService: bootstrapApiService,
    authService: authService,
    locationService: _UnusedLocationService(),
    tagApiService: _UnusedTagApiService(),
    recordSubmissionApiService: _UnusedRecordSubmissionApiService(),
  );
}

BootstrapData _emptyBootstrapData() {
  return BootstrapData(
    requestId: 'request-1',
    serverTime: DateTime.parse('2026-07-31T16:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '4-2.1',
    buildings: const <Building>[],
    tags: const <BuildingTag>[],
    counts: const BootstrapCounts(buildings: 0, visits: 0, photos: 0, tags: 0),
  );
}

class _RefreshableAuthService extends AuthService {
  String _idToken = 'expired';
  int refreshCallCount = 0;

  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser? get currentUser =>
      const AuthenticatedGoogleUser(email: 'test@example.com');

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> refreshIdToken() async {
    refreshCallCount += 1;
    _idToken = 'fresh';
    notifyListeners();
    return true;
  }

  @override
  Future<void> signOut() async {}
}

class _ExpiringBootstrapApiService implements BootstrapApiService {
  final List<String> receivedTokens = <String>[];

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    receivedTokens.add(idToken);
    if (idToken == 'expired') {
      throw const BootstrapApiException(
        'IDトークンが無効または期限切れです。',
        errorCode: 'AUTH_REQUIRED',
      );
    }
    return _emptyBootstrapData();
  }

  @override
  void close() {}
}

class _EmptyImagePickerService implements RecordImagePickerService {
  @override
  Future<List<RecordDraftPhoto>> pickImages() async {
    return const <RecordDraftPhoto>[];
  }
}

class _UnusedLocationService extends Fake implements RecordLocationService {}

class _UnusedTagApiService extends Fake implements TagApiService {}

class _UnusedRecordSubmissionApiService extends Fake
    implements RecordSubmissionApiService {}
