import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_single_photo_submission_executor.dart';
import 'package:building_record_app/features/record/domain/record_submission_draft_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('準備payloadと確定指定を付けて写真1枚を1通信で保存する', () async {
    final UploadRecordPhotoResult uploadResult = _uploadResult(
      buildingId: 'server-building',
      visitId: 'server-visit',
      recordCompleted: true,
      photoCount: 1,
      buildingCreated: true,
      visitCreated: true,
    );
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(result: uploadResult);
    final RecordSinglePhotoSubmissionExecutor executor =
        RecordSinglePhotoSubmissionExecutor(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionDraft draft = _submissionDraft();
    final RecordDraftPhoto photo = _photo();

    final RecordSinglePhotoSubmissionAttempt attempt = await executor.submit(
      requestId: 'photo-request',
      beginRequestId: 'begin-request',
      idToken: 'id-token',
      buildingId: 'draft-building',
      visitId: 'draft-visit',
      submissionDraft: draft,
      photo: photo,
      includeRecordPreparation: true,
    );

    expect(service.lastRequestId, 'photo-request');
    expect(service.lastClientVersion, AppConfig.version);
    expect(service.lastIdToken, 'id-token');
    expect(service.lastBuildingId, 'draft-building');
    expect(service.lastVisitId, 'draft-visit');
    expect(service.lastPhotoId, photo.photoId);
    expect(service.lastTakenAt, draft.visitedAt);
    expect(service.lastLatitude, draft.location.latitude);
    expect(service.lastLongitude, draft.location.longitude);
    expect(service.lastAccuracyM, draft.location.accuracyM);
    expect(service.lastLocationSource, 'gps');
    expect(service.lastDisplayOrder, 1);
    expect(service.lastFinalizeAfterUpload, isTrue);

    final RecordPreparationPayload? preparation = service.lastRecordPreparation;
    expect(preparation, isNotNull);
    expect(preparation!.requestId, 'begin-request');
    expect(preparation.buildingMode, 'new');
    expect(preparation.buildingId, 'draft-building');
    expect(preparation.visitId, 'draft-visit');
    expect(preparation.buildingName, 'テスト建物');
    expect(preparation.designTagIds, <String>['design-a', 'design-b']);
    expect(preparation.triggerTagIds, <String>['trigger-a', 'trigger-b']);
    expect(preparation.expectedPhotoCount, 1);

    expect(attempt.uploadResult, same(uploadResult));
    expect(attempt.errorMessage, isNull);
    expect(attempt.beginRecordResult?.buildingId, 'server-building');
    expect(attempt.beginRecordResult?.visitId, 'server-visit');
    expect(attempt.beginRecordResult?.expectedPhotoCount, 1);
    expect(attempt.beginRecordResult?.buildingCreated, isTrue);
    expect(attempt.beginRecordResult?.visitCreated, isTrue);
    expect(attempt.finalizeRecordResult?.buildingId, 'server-building');
    expect(attempt.finalizeRecordResult?.visitId, 'server-visit');
    expect(attempt.finalizeRecordResult?.photoCount, 1);
    expect(attempt.finalizeRecordResult?.status, 'completed');
  });

  test('再送時は準備payloadを付けず同じ写真保存経路を使う', () async {
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(
          result: _uploadResult(
            buildingId: null,
            visitId: null,
            recordCompleted: true,
            photoCount: 1,
          ),
        );
    final RecordSinglePhotoSubmissionExecutor executor =
        RecordSinglePhotoSubmissionExecutor(
          recordSubmissionApiService: service,
        );

    final RecordSinglePhotoSubmissionAttempt attempt = await executor.submit(
      requestId: 'same-photo-request',
      beginRequestId: 'same-begin-request',
      idToken: 'id-token',
      buildingId: 'existing-building',
      visitId: 'existing-visit',
      submissionDraft: _submissionDraft(),
      photo: _photo(),
      includeRecordPreparation: false,
    );

    expect(service.lastRequestId, 'same-photo-request');
    expect(service.lastRecordPreparation, isNull);
    expect(service.lastFinalizeAfterUpload, isTrue);
    expect(attempt.beginRecordResult?.buildingId, 'existing-building');
    expect(attempt.beginRecordResult?.visitId, 'existing-visit');
    expect(attempt.finalizeRecordResult?.buildingId, 'existing-building');
    expect(attempt.finalizeRecordResult?.visitId, 'existing-visit');
  });

  test('サーバーが未確定を返した場合は確定結果を作らない', () async {
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(
          result: _uploadResult(
            buildingId: 'building-1',
            visitId: 'visit-1',
            recordCompleted: false,
            photoCount: null,
          ),
        );
    final RecordSinglePhotoSubmissionExecutor executor =
        RecordSinglePhotoSubmissionExecutor(
          recordSubmissionApiService: service,
        );

    final RecordSinglePhotoSubmissionAttempt attempt = await executor.submit(
      requestId: 'photo-request',
      beginRequestId: 'begin-request',
      idToken: 'id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: _submissionDraft(),
      photo: _photo(),
      includeRecordPreparation: true,
    );

    expect(attempt.uploadResult, isNotNull);
    expect(attempt.beginRecordResult, isNotNull);
    expect(attempt.finalizeRecordResult, isNull);
  });

  test('AUTH_REQUIREDを認証更新が必要な失敗結果へ変換する', () async {
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(
          result: _uploadResult(recordCompleted: true, photoCount: 1),
          uploadError: const RecordSubmissionApiException(
            '認証が必要です。',
            errorCode: 'AUTH_REQUIRED',
          ),
        );
    final RecordSinglePhotoSubmissionExecutor executor =
        RecordSinglePhotoSubmissionExecutor(
          recordSubmissionApiService: service,
        );

    final RecordSinglePhotoSubmissionAttempt attempt = await executor.submit(
      requestId: 'photo-request',
      beginRequestId: 'begin-request',
      idToken: 'expired-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: _submissionDraft(),
      photo: _photo(),
      includeRecordPreparation: true,
    );

    expect(attempt.uploadResult, isNull);
    expect(attempt.errorMessage, '認証が必要です。');
    expect(attempt.authenticationRequired, isTrue);
  });

  test('予期しない例外を不明なエラーへ変換する', () async {
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(
          result: _uploadResult(recordCompleted: true, photoCount: 1),
          uploadError: StateError('unexpected'),
        );
    final RecordSinglePhotoSubmissionExecutor executor =
        RecordSinglePhotoSubmissionExecutor(
          recordSubmissionApiService: service,
        );

    final RecordSinglePhotoSubmissionAttempt attempt = await executor.submit(
      requestId: 'photo-request',
      beginRequestId: 'begin-request',
      idToken: 'id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: _submissionDraft(),
      photo: _photo(),
      includeRecordPreparation: true,
    );

    expect(attempt.uploadResult, isNull);
    expect(attempt.errorMessage, '不明なエラー');
    expect(attempt.authenticationRequired, isFalse);
  });
}

RecordSubmissionDraft _submissionDraft() {
  return RecordSubmissionDraftBuilder.build(
    isNewBuilding: true,
    newBuildingName: '  テスト建物  ',
    newDesignTagIds: const <String>['design-b', 'design-a'],
    newSalesTagIds: const <String>['sales-a'],
    newConstructionTagIds: const <String>['construction-a'],
    pendingExistingDesignTagIds: const <String>[],
    pendingExistingSalesTagIds: const <String>[],
    pendingExistingConstructionTagIds: const <String>[],
    buildingId: 'draft-building',
    visitId: 'draft-visit',
    visitedAt: DateTime.parse('2026-08-27T10:00:00+09:00'),
    triggerTagIds: const <String>['trigger-b', 'trigger-a'],
    impression: '  保存テスト  ',
    location: RecordDraftLocation(
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      source: RecordLocationSource.gps,
      capturedAt: DateTime.parse('2026-08-27T09:59:00+09:00'),
    ),
    expectedPhotoCount: 1,
  );
}

RecordDraftPhoto _photo() {
  return RecordDraftPhoto(
    photoId: 'photo-1',
    fileName: 'photo.jpg',
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  );
}

UploadRecordPhotoResult _uploadResult({
  String? buildingId,
  String? visitId,
  required bool recordCompleted,
  required int? photoCount,
  bool buildingCreated = false,
  bool visitCreated = false,
}) {
  return UploadRecordPhotoResult(
    photoId: 'photo-1',
    storageFileId: 'storage-photo-1',
    byteSize: 4,
    displayOrder: 1,
    reused: false,
    buildingId: buildingId,
    visitId: visitId,
    recordPrepared: true,
    buildingCreated: buildingCreated,
    visitCreated: visitCreated,
    recordCompleted: recordCompleted,
    photoCount: photoCount,
    saveMode: 'combined_photo_step',
  );
}

class _FakeRecordSubmissionApiService implements RecordSubmissionApiService {
  _FakeRecordSubmissionApiService({required this.result, this.uploadError});

  final UploadRecordPhotoResult result;
  final Object? uploadError;

  String? lastRequestId;
  String? lastClientVersion;
  String? lastIdToken;
  String? lastBuildingId;
  String? lastVisitId;
  String? lastPhotoId;
  DateTime? lastTakenAt;
  double? lastLatitude;
  double? lastLongitude;
  double? lastAccuracyM;
  String? lastLocationSource;
  int? lastDisplayOrder;
  RecordPreparationPayload? lastRecordPreparation;
  bool? lastFinalizeAfterUpload;

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
    lastRequestId = requestId;
    lastClientVersion = clientVersion;
    lastIdToken = idToken;
    lastBuildingId = buildingId;
    lastVisitId = visitId;
    lastPhotoId = photoId;
    lastTakenAt = takenAt;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastAccuracyM = accuracyM;
    lastLocationSource = locationSource;
    lastDisplayOrder = displayOrder;
    lastRecordPreparation = recordPreparation;
    lastFinalizeAfterUpload = finalizeAfterUpload;

    final Object? error = uploadError;
    if (error != null) {
      throw error;
    }
    return result;
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
  }) {
    throw StateError('beginRecord should not be called');
  }

  @override
  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    throw StateError('finalizeRecord should not be called');
  }

  @override
  void close() {}
}
