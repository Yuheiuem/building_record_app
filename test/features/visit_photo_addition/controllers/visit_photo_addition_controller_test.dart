import 'dart:typed_data';

import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/features/visit_photo_addition/controllers/visit_photo_addition_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('既存訪問へ新しいVisitを作らず写真を追加できる', () async {
    final DateTime visitedAt = DateTime.parse('2026-08-01T10:30:00+09:00');
    final _FakeRecordSubmissionApiService submissionService =
        _FakeRecordSubmissionApiService();
    final VisitPhotoAdditionController controller =
        VisitPhotoAdditionController(
          buildingId: 'building-1',
          visitId: 'visit-1',
          authService: _FakeAuthService(),
          buildingDetailApiService: _FakeBuildingDetailApiService(
            _detail(visitedAt: visitedAt),
          ),
          imagePickerService: _FakeRecordImagePickerService(<RecordDraftPhoto>[
            _photo('photo-new-1', 'one.jpg'),
            _photo('photo-new-2', 'two.jpg'),
          ]),
          recordSubmissionApiService: submissionService,
        );

    await controller.loadDetail();
    await controller.addPhotos();
    await controller.uploadPhotos();

    expect(controller.succeeded, isTrue);
    expect(controller.uploadedPhotoCount, 2);
    expect(submissionService.beginCallCount, 0);
    expect(submissionService.finalizeCallCount, 0);
    expect(submissionService.uploadCalls, hasLength(2));

    final _UploadCall first = submissionService.uploadCalls[0];
    final _UploadCall second = submissionService.uploadCalls[1];

    expect(first.buildingId, 'building-1');
    expect(first.visitId, 'visit-1');
    expect(first.photoId, 'photo-new-1');
    expect(first.displayOrder, 4);
    expect(first.takenAt, visitedAt);
    expect(first.latitude, 35.6813);
    expect(first.longitude, 139.7672);
    expect(first.accuracyM, 8.5);
    expect(first.locationSource, 'gps');

    expect(second.buildingId, 'building-1');
    expect(second.visitId, 'visit-1');
    expect(second.photoId, 'photo-new-2');
    expect(second.displayOrder, 5);
  });

  test('失敗後は送信済み写真を再送せず未完了写真だけ再送する', () async {
    final _FakeRecordSubmissionApiService submissionService =
        _FakeRecordSubmissionApiService(
          failOncePhotoIds: <String>{'photo-new-2'},
        );
    final VisitPhotoAdditionController controller =
        VisitPhotoAdditionController(
          buildingId: 'building-1',
          visitId: 'visit-1',
          authService: _FakeAuthService(),
          buildingDetailApiService: _FakeBuildingDetailApiService(_detail()),
          imagePickerService: _FakeRecordImagePickerService(<RecordDraftPhoto>[
            _photo('photo-new-1', 'one.jpg'),
            _photo('photo-new-2', 'two.jpg'),
          ]),
          recordSubmissionApiService: submissionService,
        );

    await controller.loadDetail();
    await controller.addPhotos();
    await controller.uploadPhotos();

    expect(controller.succeeded, isFalse);
    expect(controller.uploadedPhotoCount, 1);
    expect(controller.failedPhotoCount, 1);
    expect(submissionService.uploadCountFor('photo-new-1'), 1);
    expect(submissionService.uploadCountFor('photo-new-2'), 1);

    await controller.uploadPhotos();

    expect(controller.succeeded, isTrue);
    expect(controller.uploadedPhotoCount, 2);
    expect(submissionService.uploadCountFor('photo-new-1'), 1);
    expect(submissionService.uploadCountFor('photo-new-2'), 2);
  });
}

RecordDraftPhoto _photo(String id, String fileName) {
  return RecordDraftPhoto(
    photoId: id,
    fileName: fileName,
    mimeType: 'image/jpeg',
    bytes: Uint8List(1200),
  );
}

BuildingDetailData _detail({DateTime? visitedAt}) {
  final DateTime targetVisitedAt =
      visitedAt ?? DateTime.parse('2026-08-01T10:30:00+09:00');

  return BuildingDetailData(
    requestId: 'request-detail',
    serverTime: DateTime.parse('2026-08-03T12:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '5-1C',
    building: const Building(
      buildingId: 'building-1',
      buildingName: 'テスト建物',
      searchName: 'てすとたてもの',
      latitude: 35.6812,
      longitude: 139.7671,
      address: '東京都千代田区',
      designTags: <String>[],
      salesTags: <String>[],
      constructionTags: <String>[],
      driveFolderId: null,
      coverPhotoId: null,
      createdAt: null,
      updatedAt: null,
      isDeleted: false,
    ),
    visits: <BuildingVisit>[
      BuildingVisit(
        visitId: 'visit-1',
        buildingId: 'building-1',
        visitedAt: targetVisitedAt,
        triggerTags: const <String>[],
        impression: '見学記録',
        latitude: 35.6813,
        longitude: 139.7672,
        accuracyM: 8.5,
        locationSource: 'gps',
        status: 'completed',
        expectedPhotoCount: 1,
        createdAt: null,
        updatedAt: null,
      ),
    ],
    photos: <BuildingPhoto>[
      BuildingPhoto(
        photoId: 'photo-existing',
        buildingId: 'building-1',
        visitId: 'visit-1',
        fileName: 'existing.jpg',
        mimeType: 'image/jpeg',
        byteSize: 800,
        width: 100,
        height: 100,
        takenAt: targetVisitedAt,
        latitude: 35.6813,
        longitude: 139.7672,
        accuracyM: 8.5,
        locationSource: 'gps',
        displayOrder: 3,
        createdAt: null,
      ),
    ],
    tags: const <BuildingTag>[],
    counts: const BuildingDetailCounts(visits: 1, photos: 1),
  );
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser =>
      const AuthenticatedGoogleUser(email: 'test@example.com');

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeBuildingDetailApiService implements BuildingDetailApiService {
  const _FakeBuildingDetailApiService(this.detail);

  final BuildingDetailData detail;

  @override
  Future<BuildingDetailData> getBuildingDetail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    return detail;
  }

  @override
  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}

class _FakeRecordImagePickerService implements RecordImagePickerService {
  const _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async {
    return List<RecordDraftPhoto>.from(photos);
  }
}

class _FakeRecordSubmissionApiService
    implements RecordSubmissionApiService {
  _FakeRecordSubmissionApiService({
    this.failOncePhotoIds = const <String>{},
  });

  final Set<String> failOncePhotoIds;
  final List<_UploadCall> uploadCalls = <_UploadCall>[];
  final Map<String, int> _uploadCounts = <String, int>{};
  int beginCallCount = 0;
  int finalizeCallCount = 0;

  int uploadCountFor(String photoId) => _uploadCounts[photoId] ?? 0;

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
  }) {
    beginCallCount += 1;
    throw UnimplementedError();
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
    final int uploadCount = (_uploadCounts[photoId] ?? 0) + 1;
    _uploadCounts[photoId] = uploadCount;
    uploadCalls.add(
      _UploadCall(
        buildingId: buildingId,
        visitId: visitId,
        photoId: photoId,
        takenAt: takenAt,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        locationSource: locationSource,
        displayOrder: displayOrder,
      ),
    );

    if (failOncePhotoIds.contains(photoId) && uploadCount == 1) {
      throw const RecordSubmissionApiException('一時的な送信失敗');
    }

    return UploadRecordPhotoResult(
      photoId: photoId,
      storageFileId: 'drive-$photoId',
      byteSize: bytes.length,
      displayOrder: displayOrder,
      reused: false,
    );
  }

  @override
  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    finalizeCallCount += 1;
    throw UnimplementedError();
  }

  @override
  void close() {}
}

class _UploadCall {
  const _UploadCall({
    required this.buildingId,
    required this.visitId,
    required this.photoId,
    required this.takenAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationSource,
    required this.displayOrder,
  });

  final String buildingId;
  final String visitId;
  final String photoId;
  final DateTime takenAt;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String locationSource;
  final int displayOrder;
}
