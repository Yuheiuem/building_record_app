import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_photo_upload_executor.dart';
import 'package:building_record_app/features/record/domain/record_submission_draft_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('複数写真の1枚分を既存payloadのままServiceへ渡す', () async {
    const UploadRecordPhotoResult expectedResult = UploadRecordPhotoResult(
      photoId: 'photo-1',
      storageFileId: 'storage-photo-1',
      byteSize: 4,
      displayOrder: 2,
      reused: false,
      buildingId: 'building-response',
      visitId: 'visit-response',
    );
    final _FakeRecordSubmissionApiService service =
        _FakeRecordSubmissionApiService(result: expectedResult);
    final RecordPhotoUploadExecutor executor = RecordPhotoUploadExecutor(
      recordSubmissionApiService: service,
    );
    final RecordDraftPhoto photo = RecordDraftPhoto(
      photoId: 'photo-1',
      fileName: 'photo-1.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );
    final RecordSubmissionDraft draft = _draft();

    final RecordPhotoUploadAttempt attempt = await executor.upload(
      requestId: 'photo-request-1',
      idToken: 'id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: draft,
      photo: photo,
      displayOrder: 2,
    );

    expect(attempt.photo, same(photo));
    expect(attempt.result, same(expectedResult));
    expect(attempt.errorMessage, isNull);
    expect(attempt.errorCode, isNull);
    expect(attempt.authenticationRequired, isFalse);
    expect(service.requestId, 'photo-request-1');
    expect(service.clientVersion, AppConfig.version);
    expect(service.idToken, 'id-token');
    expect(service.buildingId, 'building-1');
    expect(service.visitId, 'visit-1');
    expect(service.photoId, 'photo-1');
    expect(service.fileName, 'photo-1.jpg');
    expect(service.mimeType, 'image/jpeg');
    expect(service.bytes, same(photo.bytes));
    expect(service.takenAt, draft.visitedAt);
    expect(service.latitude, draft.location.latitude);
    expect(service.longitude, draft.location.longitude);
    expect(service.accuracyM, draft.location.accuracyM);
    expect(service.locationSource, draft.location.source.apiValue);
    expect(service.displayOrder, 2);
    expect(service.recordPreparation, isNull);
    expect(service.finalizeAfterUpload, isFalse);
  });

  test('AUTH_REQUIREDを認証更新が必要な失敗結果へ変換する', () async {
    final RecordPhotoUploadExecutor executor = RecordPhotoUploadExecutor(
      recordSubmissionApiService: _FakeRecordSubmissionApiService(
        apiError: const RecordSubmissionApiException(
          'IDトークンが期限切れです。',
          errorCode: 'AUTH_REQUIRED',
        ),
      ),
    );
    final RecordDraftPhoto photo = _photo();

    final RecordPhotoUploadAttempt attempt = await executor.upload(
      requestId: 'photo-request-auth',
      idToken: 'expired-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: _draft(),
      photo: photo,
      displayOrder: 1,
    );

    expect(attempt.photo, same(photo));
    expect(attempt.result, isNull);
    expect(attempt.errorMessage, 'IDトークンが期限切れです。');
    expect(attempt.errorCode, 'AUTH_REQUIRED');
    expect(attempt.authenticationRequired, isTrue);
  });

  test('予期しない例外を不明なエラーとして返す', () async {
    final RecordPhotoUploadExecutor executor = RecordPhotoUploadExecutor(
      recordSubmissionApiService: _FakeRecordSubmissionApiService(
        throwUnexpectedError: true,
      ),
    );

    final RecordPhotoUploadAttempt attempt = await executor.upload(
      requestId: 'photo-request-unknown',
      idToken: 'id-token',
      buildingId: 'building-1',
      visitId: 'visit-1',
      submissionDraft: _draft(),
      photo: _photo(),
      displayOrder: 1,
    );

    expect(attempt.result, isNull);
    expect(attempt.errorMessage, '不明なエラー');
    expect(attempt.errorCode, isNull);
    expect(attempt.authenticationRequired, isFalse);
  });
}

RecordSubmissionDraft _draft() {
  return RecordSubmissionDraftBuilder.build(
    isNewBuilding: true,
    newBuildingName: 'テスト建物',
    newDesignTagIds: const <String>['design-1'],
    newSalesTagIds: const <String>['sales-1'],
    newConstructionTagIds: const <String>['construction-1'],
    pendingExistingDesignTagIds: const <String>[],
    pendingExistingSalesTagIds: const <String>[],
    pendingExistingConstructionTagIds: const <String>[],
    buildingId: 'building-1',
    visitId: 'visit-1',
    visitedAt: DateTime.parse('2026-08-27T10:00:00+09:00'),
    triggerTagIds: const <String>['trigger-1'],
    impression: '送信テスト',
    location: RecordDraftLocation(
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      source: RecordLocationSource.gps,
      capturedAt: DateTime.parse('2026-08-27T09:59:00+09:00'),
    ),
    expectedPhotoCount: 2,
  );
}

RecordDraftPhoto _photo() {
  return RecordDraftPhoto(
    photoId: 'photo-1',
    fileName: 'photo-1.jpg',
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
  );
}

class _FakeRecordSubmissionApiService
    implements RecordSubmissionApiService {
  _FakeRecordSubmissionApiService({
    this.result,
    this.apiError,
    this.throwUnexpectedError = false,
  });

  final UploadRecordPhotoResult? result;
  final RecordSubmissionApiException? apiError;
  final bool throwUnexpectedError;

  String? requestId;
  String? clientVersion;
  String? idToken;
  String? buildingId;
  String? visitId;
  String? photoId;
  String? fileName;
  String? mimeType;
  Uint8List? bytes;
  DateTime? takenAt;
  double? latitude;
  double? longitude;
  double? accuracyM;
  String? locationSource;
  int? displayOrder;
  RecordPreparationPayload? recordPreparation;
  bool? finalizeAfterUpload;

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
    this.requestId = requestId;
    this.clientVersion = clientVersion;
    this.idToken = idToken;
    this.buildingId = buildingId;
    this.visitId = visitId;
    this.photoId = photoId;
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.bytes = bytes;
    this.takenAt = takenAt;
    this.latitude = latitude;
    this.longitude = longitude;
    this.accuracyM = accuracyM;
    this.locationSource = locationSource;
    this.displayOrder = displayOrder;
    this.recordPreparation = recordPreparation;
    this.finalizeAfterUpload = finalizeAfterUpload;

    final RecordSubmissionApiException? failure = apiError;
    if (failure != null) {
      throw failure;
    }
    if (throwUnexpectedError) {
      throw StateError('unexpected');
    }
    return result!;
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
    throw UnimplementedError();
  }

  @override
  Future<FinalizeRecordResult> finalizeRecord({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) {
    throw UnimplementedError();
  }

  @override
  void close() {}
}
