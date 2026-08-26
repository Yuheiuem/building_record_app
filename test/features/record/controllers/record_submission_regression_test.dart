import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/data/services/tag_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('下書き検証', () {
    test('写真がない場合はAPIを呼ばずに保存を止める', () async {
      final _ControllerHarness harness = _createHarness();
      final RecordDraftController controller = harness.controller;

      controller.setNewBuildingName('検証用建物');
      await controller.acquireCurrentLocation();
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.idle);
      expect(controller.submissionErrorMessage, '写真を1枚以上選択してください。');
      expect(harness.submissionService.totalApiCallCount, 0);
    });

    test('新規建物名がない場合はAPIを呼ばずに保存を止める', () async {
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-validation-name')],
      );
      final RecordDraftController controller = harness.controller;

      await controller.addPhotos();
      await controller.acquireCurrentLocation();
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.idle);
      expect(controller.submissionErrorMessage, '建物名を入力してください。');
      expect(harness.submissionService.totalApiCallCount, 0);
    });

    test('既存建物が未選択の場合はAPIを呼ばずに保存を止める', () async {
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-validation-existing')],
      );
      final RecordDraftController controller = harness.controller;

      await controller.addPhotos();
      controller.setBuildingMode(RecordBuildingMode.existingBuilding);
      await controller.acquireCurrentLocation();
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.idle);
      expect(controller.submissionErrorMessage, '登録済みの建物を選択してください。');
      expect(harness.submissionService.totalApiCallCount, 0);
    });

    test('位置がない場合はAPIを呼ばずに保存を止める', () async {
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-validation-location')],
      );
      final RecordDraftController controller = harness.controller;

      await controller.addPhotos();
      controller.setNewBuildingName('位置未設定建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.idle);
      expect(controller.submissionErrorMessage, '位置情報を取得してください。');
      expect(harness.submissionService.totalApiCallCount, 0);
    });
  });

  group('送信セッションと再送', () {
    test('写真1枚の失敗後も同じrequestIdで一括保存を再送する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(
            failOncePhotoIds: <String>{'photo-single-retry'},
          );
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-single-retry')],
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: '1枚再送建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.failed);
      expect(controller.isDraftLocked, isTrue);
      expect(submissionService.beginRequestIds, isEmpty);
      expect(submissionService.finalizeRequestIds, isEmpty);
      expect(
        submissionService.uploadRequestIds['photo-single-retry'],
        hasLength(1),
      );

      await controller.submitRecord();

      final List<String> uploadRequestIds =
          submissionService.uploadRequestIds['photo-single-retry']!;
      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(uploadRequestIds, hasLength(2));
      expect(uploadRequestIds.toSet(), hasLength(1));
      expect(submissionService.preparationRequestIds, hasLength(2));
      expect(submissionService.preparationRequestIds.toSet(), hasLength(1));
      expect(submissionService.beginRequestIds, isEmpty);
      expect(submissionService.finalizeRequestIds, isEmpty);
      expect(submissionService.combinedFinalizeCallCount, 1);
    });

    test('準備通信失敗後は下書きを固定し同じrequestIdで再試行する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(failBeginAttempts: 1);
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[
          _photo('photo-begin-1'),
          _photo('photo-begin-2'),
        ],
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(
        controller,
        buildingName: '準備再送建物',
        impression: '準備通信失敗前の入力',
      );
      final RecordDraftLocation originalLocation = controller.visitLocation!;

      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.failed);
      expect(controller.isDraftLocked, isTrue);
      expect(submissionService.beginRequestIds, hasLength(1));
      expect(submissionService.uploadCallCount, isEmpty);
      expect(submissionService.finalizeRequestIds, isEmpty);

      controller.setNewBuildingName('変更されてはいけない建物名');
      controller.setImpression('変更されてはいけない感想');
      controller.removePhoto('photo-begin-1');
      controller.clearVisitLocation();
      controller.setBuildingMode(RecordBuildingMode.existingBuilding);

      expect(controller.newBuildingName, '準備再送建物');
      expect(controller.impression, '準備通信失敗前の入力');
      expect(controller.photoCount, 2);
      expect(controller.visitLocation, same(originalLocation));
      expect(controller.buildingMode, RecordBuildingMode.newBuilding);

      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.beginRequestIds, hasLength(2));
      expect(submissionService.beginRequestIds.toSet(), hasLength(1));
      expect(submissionService.uploadCallCount['photo-begin-1'], 1);
      expect(submissionService.uploadCallCount['photo-begin-2'], 1);
      expect(submissionService.finalizeRequestIds, hasLength(1));
    });

    test('一部写真失敗後は成功写真を再送せず失敗写真だけ同じrequestIdで再送する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(
            failOncePhotoIds: <String>{'photo-partial-2'},
          );
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[
          _photo('photo-partial-1'),
          _photo('photo-partial-2'),
        ],
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: '部分再送建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.failed);
      expect(controller.uploadedPhotoCount, 1);
      expect(controller.failedPhotoCount, 1);
      expect(submissionService.finalizeRequestIds, isEmpty);

      await controller.submitRecord();

      final List<String> failedPhotoRequestIds =
          submissionService.uploadRequestIds['photo-partial-2']!;
      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.beginRequestIds, hasLength(1));
      expect(submissionService.uploadCallCount['photo-partial-1'], 1);
      expect(submissionService.uploadCallCount['photo-partial-2'], 2);
      expect(failedPhotoRequestIds.toSet(), hasLength(1));
      expect(submissionService.finalizeRequestIds, hasLength(1));
    });

    test('確定通信失敗後は写真を再送せず同じfinalize requestIdで再試行する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(failFinalizeAttempts: 1);
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[
          _photo('photo-finalize-1'),
          _photo('photo-finalize-2'),
        ],
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: '確定再送建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.failed);
      expect(controller.uploadedPhotoCount, 2);
      expect(submissionService.beginRequestIds, hasLength(1));
      expect(submissionService.uploadCallCount['photo-finalize-1'], 1);
      expect(submissionService.uploadCallCount['photo-finalize-2'], 1);
      expect(submissionService.finalizeRequestIds, hasLength(1));

      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.beginRequestIds, hasLength(1));
      expect(submissionService.uploadCallCount['photo-finalize-1'], 1);
      expect(submissionService.uploadCallCount['photo-finalize-2'], 1);
      expect(submissionService.finalizeRequestIds, hasLength(2));
      expect(submissionService.finalizeRequestIds.toSet(), hasLength(1));
    });

    test('5枚の写真は4件のwaveと残り1件に分けて送信する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(
            uploadDelay: const Duration(milliseconds: 15),
          );
      final _ControllerHarness harness = _createHarness(
        photos: List<RecordDraftPhoto>.generate(
          5,
          (int index) => _photo('photo-wave-${index + 1}'),
        ),
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: 'wave確認建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.maxConcurrentUploadCount, 4);
      expect(submissionService.uploadCallCount.length, 5);
      expect(submissionService.uploadCallCount.values, everyElement(equals(1)));
      expect(submissionService.beginRequestIds, hasLength(1));
      expect(submissionService.finalizeRequestIds, hasLength(1));
    });
  });

  group('認証復旧', () {
    test('保存前にトークン期限が近い場合は更新後のトークンだけで送信する', () async {
      final _ConfigurableAuthService authService = _ConfigurableAuthService(
        idToken: 'near-expiry-token',
        tokenValid: false,
        refreshedToken: 'fresh-token',
      );
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService();
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-preflight-auth')],
        authService: authService,
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: '認証更新建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(authService.refreshCallCount, 1);
      expect(submissionService.uploadTokens['photo-preflight-auth'], <String>[
        'fresh-token',
      ]);
    });

    test('写真送信中のAUTH_REQUIRED後も下書きと成功写真を保持して再開する', () async {
      final _ConfigurableAuthService authService = _ConfigurableAuthService(
        idToken: 'expired-token',
        refreshedToken: 'fresh-token',
      );
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService(
            authRequiredOncePhotoIds: <String>{'photo-auth-2'},
          );
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[
          _photo('photo-auth-1'),
          _photo('photo-auth-2'),
        ],
        authService: authService,
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(controller, buildingName: '認証再開建物');
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.failed);
      expect(controller.requiresReauthentication, isTrue);
      expect(controller.uploadedPhotoCount, 1);
      expect(controller.failedPhotoCount, 1);
      expect(controller.photoCount, 2);

      await controller.refreshAuthentication();
      await Future<void>.delayed(Duration.zero);

      expect(authService.refreshCallCount, 1);
      expect(controller.requiresReauthentication, isFalse);

      await controller.submitRecord();

      final List<String> retryRequestIds =
          submissionService.uploadRequestIds['photo-auth-2']!;
      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.uploadCallCount['photo-auth-1'], 1);
      expect(submissionService.uploadCallCount['photo-auth-2'], 2);
      expect(retryRequestIds.toSet(), hasLength(1));
      expect(submissionService.uploadTokens['photo-auth-2'], <String>[
        'expired-token',
        'fresh-token',
      ]);
    });
  });

  group('payloadとリセット', () {
    test('既存建物では建物名を送らず今回追加するタグだけを送信する', () async {
      final _RecordingRecordSubmissionApiService submissionService =
          _RecordingRecordSubmissionApiService();
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[
          _photo('photo-existing-1'),
          _photo('photo-existing-2'),
        ],
        bootstrapData: _existingBuildingBootstrapData(),
        submissionService: submissionService,
      );
      final RecordDraftController controller = harness.controller;

      await controller.loadBootstrapData();
      await controller.addPhotos();
      controller.setBuildingMode(RecordBuildingMode.existingBuilding);
      controller.selectExistingBuilding('building-existing');
      controller.toggleExistingBuildingTag(
        BuildingTagType.design,
        'tag-design-add',
      );
      controller.toggleTriggerTag('tag-trigger-1');
      controller.setImpression('既存建物への再訪');
      await controller.acquireCurrentLocation();
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(submissionService.lastBuildingMode, 'existing');
      expect(submissionService.lastBuildingId, 'building-existing');
      expect(submissionService.lastBuildingName, isNull);
      expect(submissionService.lastDesignTagIds, <String>['tag-design-add']);
      expect(submissionService.lastTriggerTagIds, <String>['tag-trigger-1']);
      expect(submissionService.lastImpression, '既存建物への再訪');
    });

    test('保存完了後に新しい記録を始めると送信セッションを初期化する', () async {
      final _RecordingBootstrapApiService bootstrapService =
          _RecordingBootstrapApiService(_emptyBootstrapData());
      final _ControllerHarness harness = _createHarness(
        photos: <RecordDraftPhoto>[_photo('photo-reset')],
        bootstrapService: bootstrapService,
      );
      final RecordDraftController controller = harness.controller;

      await _prepareNewBuilding(
        controller,
        buildingName: 'リセット前建物',
        impression: 'リセット前の感想',
      );
      await controller.submitRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.succeeded);
      expect(controller.photoCount, 1);
      expect(controller.draftRevision, 0);
      expect(bootstrapService.callCount, 1);

      await controller.startNewRecord();

      expect(controller.submissionPhase, RecordSubmissionPhase.idle);
      expect(controller.photoCount, 0);
      expect(controller.uploadedPhotoCount, 0);
      expect(controller.newBuildingName, isEmpty);
      expect(controller.impression, isEmpty);
      expect(controller.visitLocation, isNull);
      expect(controller.buildingMode, RecordBuildingMode.newBuilding);
      expect(controller.isDraftLocked, isFalse);
      expect(controller.draftRevision, 1);
      expect(bootstrapService.callCount, 2);
    });
  });
}

Future<void> _prepareNewBuilding(
  RecordDraftController controller, {
  required String buildingName,
  String impression = '',
}) async {
  await controller.addPhotos();
  controller.setNewBuildingName(buildingName);
  controller.setImpression(impression);
  await controller.acquireCurrentLocation();
}

_ControllerHarness _createHarness({
  List<RecordDraftPhoto> photos = const <RecordDraftPhoto>[],
  BootstrapData? bootstrapData,
  _ConfigurableAuthService? authService,
  _RecordingBootstrapApiService? bootstrapService,
  _RecordingRecordSubmissionApiService? submissionService,
}) {
  final _ConfigurableAuthService resolvedAuthService =
      authService ?? _ConfigurableAuthService();
  final _RecordingBootstrapApiService resolvedBootstrapService =
      bootstrapService ??
      _RecordingBootstrapApiService(bootstrapData ?? _emptyBootstrapData());
  final _RecordingRecordSubmissionApiService resolvedSubmissionService =
      submissionService ?? _RecordingRecordSubmissionApiService();
  final RecordDraftController controller = RecordDraftController(
    imagePickerService: _FakeRecordImagePickerService(photos),
    bootstrapApiService: resolvedBootstrapService,
    authService: resolvedAuthService,
    locationService: _FakeRecordLocationService(_gpsLocation()),
    tagApiService: _UnusedTagApiService(),
    recordSubmissionApiService: resolvedSubmissionService,
  );
  addTearDown(controller.dispose);
  return _ControllerHarness(
    controller: controller,
    submissionService: resolvedSubmissionService,
  );
}

RecordDraftPhoto _photo(String photoId) {
  return RecordDraftPhoto(
    photoId: photoId,
    fileName: '$photoId.jpg',
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  );
}

RecordDraftLocation _gpsLocation() {
  return RecordDraftLocation(
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 8.4,
    source: RecordLocationSource.gps,
    capturedAt: DateTime.parse('2026-08-26T14:00:00+09:00'),
  );
}

BootstrapData _emptyBootstrapData() {
  return BootstrapData(
    requestId: 'bootstrap-empty',
    serverTime: DateTime.parse('2026-08-26T14:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '5-6.3A',
    buildings: const <Building>[],
    tags: const <BuildingTag>[],
    counts: const BootstrapCounts(buildings: 0, visits: 0, photos: 0, tags: 0),
  );
}

BootstrapData _existingBuildingBootstrapData() {
  return BootstrapData(
    requestId: 'bootstrap-existing',
    serverTime: DateTime.parse('2026-08-26T14:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '5-6.3A',
    buildings: const <Building>[
      Building(
        buildingId: 'building-existing',
        buildingName: '登録済み建物',
        searchName: '登録済み建物',
        latitude: 35.681236,
        longitude: 139.767125,
        address: '東京都千代田区',
        designTags: <String>['tag-design-current'],
        salesTags: <String>[],
        constructionTags: <String>[],
        driveFolderId: null,
        coverPhotoId: null,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
    ],
    tags: <BuildingTag>[
      _tag(
        id: 'tag-design-current',
        type: BuildingTagType.design,
        name: '既存設計タグ',
        order: 1,
      ),
      _tag(
        id: 'tag-design-add',
        type: BuildingTagType.design,
        name: '今回追加する設計タグ',
        order: 2,
      ),
      _tag(
        id: 'tag-trigger-1',
        type: BuildingTagType.trigger,
        name: '再訪',
        order: 1,
      ),
    ],
    counts: const BootstrapCounts(buildings: 1, visits: 0, photos: 0, tags: 3),
  );
}

BuildingTag _tag({
  required String id,
  required BuildingTagType type,
  required String name,
  required int order,
}) {
  return BuildingTag(
    tagId: id,
    tagType: type,
    tagName: name,
    normalizedName: name,
    displayOrder: order,
    isActive: true,
    createdAt: null,
    updatedAt: null,
  );
}

class _ControllerHarness {
  const _ControllerHarness({
    required this.controller,
    required this.submissionService,
  });

  final RecordDraftController controller;
  final _RecordingRecordSubmissionApiService submissionService;
}

class _ConfigurableAuthService extends AuthService {
  _ConfigurableAuthService({
    String idToken = 'test-id-token',
    bool tokenValid = true,
    String refreshedToken = 'fresh-id-token',
    bool refreshSucceeds = true,
  }) : _idToken = idToken,
       _tokenValid = tokenValid,
       _refreshedToken = refreshedToken,
       _refreshSucceeds = refreshSucceeds;

  String _idToken;
  bool _tokenValid;
  final String _refreshedToken;
  final bool _refreshSucceeds;
  int refreshCallCount = 0;

  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser => const AuthenticatedGoogleUser(
    email: 'test@example.com',
    displayName: 'テスト利用者',
  );

  @override
  String get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  bool hasIdTokenValidity(Duration minimumValidity) {
    return _tokenValid;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> refreshIdToken() async {
    refreshCallCount += 1;
    if (!_refreshSucceeds) {
      return false;
    }
    _idToken = _refreshedToken;
    _tokenValid = true;
    notifyListeners();
    return true;
  }

  @override
  Future<void> signOut() async {}
}

class _RecordingBootstrapApiService implements BootstrapApiService {
  _RecordingBootstrapApiService(this.data);

  final BootstrapData data;
  int callCount = 0;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    return data;
  }

  @override
  void close() {}
}

class _RecordingRecordSubmissionApiService
    implements RecordSubmissionApiService {
  _RecordingRecordSubmissionApiService({
    Set<String> failOncePhotoIds = const <String>{},
    Set<String> authRequiredOncePhotoIds = const <String>{},
    int failBeginAttempts = 0,
    int failFinalizeAttempts = 0,
    this.uploadDelay = const Duration(milliseconds: 5),
  }) : _remainingPhotoFailures = <String>{...failOncePhotoIds},
       _remainingAuthFailures = <String>{...authRequiredOncePhotoIds},
       _remainingBeginFailures = failBeginAttempts,
       _remainingFinalizeFailures = failFinalizeAttempts;

  final Set<String> _remainingPhotoFailures;
  final Set<String> _remainingAuthFailures;
  int _remainingBeginFailures;
  int _remainingFinalizeFailures;
  final Duration uploadDelay;

  final List<String> beginRequestIds = <String>[];
  final List<String> finalizeRequestIds = <String>[];
  final List<String> preparationRequestIds = <String>[];
  final Map<String, List<String>> uploadRequestIds = <String, List<String>>{};
  final Map<String, List<String>> uploadTokens = <String, List<String>>{};
  final Map<String, int> uploadCallCount = <String, int>{};

  int combinedFinalizeCallCount = 0;
  int currentConcurrentUploadCount = 0;
  int maxConcurrentUploadCount = 0;

  String? lastBuildingMode;
  String? lastBuildingId;
  String? lastBuildingName;
  List<String>? lastDesignTagIds;
  List<String>? lastTriggerTagIds;
  String? lastImpression;

  String? _buildingId;
  String? _visitId;

  int get totalApiCallCount {
    final int uploadCalls = uploadCallCount.values.fold<int>(
      0,
      (int total, int value) => total + value,
    );
    return beginRequestIds.length + uploadCalls + finalizeRequestIds.length;
  }

  @override
  Future<BeginRecordResult> beginRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingMode,
    required String buildingId,
    required String visitId,
    required String? buildingName,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int expectedPhotoCount,
  }) async {
    beginRequestIds.add(requestId);
    _recordPreparationFields(
      buildingMode: buildingMode,
      buildingId: buildingId,
      visitId: visitId,
      buildingName: buildingName,
      designTagIds: designTagIds,
      triggerTagIds: triggerTagIds,
      impression: impression,
    );

    if (_remainingBeginFailures > 0) {
      _remainingBeginFailures -= 1;
      throw const RecordSubmissionApiException('テスト用の準備通信失敗');
    }

    return BeginRecordResult(
      buildingId: buildingId,
      visitId: visitId,
      expectedPhotoCount: expectedPhotoCount,
      buildingCreated: buildingMode == 'new',
      visitCreated: true,
      reused: false,
    );
  }

  @override
  Future<UploadRecordPhotoResult> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required DateTime takenAt,
    required double latitude,
    required double longitude,
    required double? accuracyM,
    required String locationSource,
    required int displayOrder,
    RecordPreparationPayload? recordPreparation,
    bool finalizeAfterUpload = false,
  }) async {
    uploadCallCount[photoId] = (uploadCallCount[photoId] ?? 0) + 1;
    uploadRequestIds.putIfAbsent(photoId, () => <String>[]).add(requestId);
    uploadTokens.putIfAbsent(photoId, () => <String>[]).add(idToken);
    currentConcurrentUploadCount += 1;
    if (currentConcurrentUploadCount > maxConcurrentUploadCount) {
      maxConcurrentUploadCount = currentConcurrentUploadCount;
    }

    try {
      await Future<void>.delayed(uploadDelay);

      if (recordPreparation != null) {
        preparationRequestIds.add(recordPreparation.requestId);
        _recordPreparationFields(
          buildingMode: recordPreparation.buildingMode,
          buildingId: recordPreparation.buildingId,
          visitId: recordPreparation.visitId,
          buildingName: recordPreparation.buildingName,
          designTagIds: recordPreparation.designTagIds,
          triggerTagIds: recordPreparation.triggerTagIds,
          impression: recordPreparation.impression,
        );
      }

      if (_remainingAuthFailures.remove(photoId)) {
        throw const RecordSubmissionApiException(
          'テスト用の認証期限切れ',
          errorCode: 'AUTH_REQUIRED',
        );
      }
      if (_remainingPhotoFailures.remove(photoId)) {
        throw const RecordSubmissionApiException('テスト用の写真送信失敗');
      }
      if (finalizeAfterUpload) {
        combinedFinalizeCallCount += 1;
      }

      return UploadRecordPhotoResult(
        photoId: photoId,
        storageFileId: 'storage-$photoId',
        byteSize: bytes.length,
        displayOrder: displayOrder,
        reused: false,
        buildingId: _buildingId ?? buildingId,
        visitId: _visitId ?? visitId,
        recordPrepared: recordPreparation != null,
        buildingCreated: recordPreparation?.buildingMode == 'new',
        visitCreated: recordPreparation != null,
        recordCompleted: finalizeAfterUpload,
        photoCount: finalizeAfterUpload ? 1 : null,
        saveMode: finalizeAfterUpload
            ? 'combined_photo_step'
            : 'parallel_photo_step',
      );
    } finally {
      currentConcurrentUploadCount -= 1;
    }
  }

  @override
  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    finalizeRequestIds.add(requestId);
    if (_remainingFinalizeFailures > 0) {
      _remainingFinalizeFailures -= 1;
      throw const RecordSubmissionApiException('テスト用の確定通信失敗');
    }
    return FinalizeRecordResult(
      buildingId: _buildingId ?? buildingId,
      visitId: _visitId ?? visitId,
      photoCount: uploadCallCount.length,
      status: 'completed',
      reused: false,
    );
  }

  void _recordPreparationFields({
    required String buildingMode,
    required String buildingId,
    required String visitId,
    required String? buildingName,
    required List<String> designTagIds,
    required List<String> triggerTagIds,
    required String impression,
  }) {
    lastBuildingMode = buildingMode;
    lastBuildingId = buildingId;
    lastBuildingName = buildingName;
    lastDesignTagIds = List<String>.of(designTagIds);
    lastTriggerTagIds = List<String>.of(triggerTagIds);
    lastImpression = impression;
    _buildingId = buildingId;
    _visitId = visitId;
  }

  @override
  void close() {}
}

class _FakeRecordImagePickerService implements RecordImagePickerService {
  const _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
}

class _FakeRecordLocationService implements RecordLocationService {
  const _FakeRecordLocationService(this.location);

  final RecordDraftLocation location;

  @override
  Future<RecordDraftLocation> getCurrentLocation() async => location;
}

class _UnusedTagApiService extends Fake implements TagApiService {}
