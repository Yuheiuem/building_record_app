import 'dart:typed_data';

import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/data/services/record_submission_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:building_record_app/features/record/domain/record_submission_draft_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('写真5枚を4件と1件のwaveに分けてbegin後にfinalizeする', () async {
    final List<RecordDraftPhoto> photos = _photos(5);
    final _RecordingSubmissionService service = _RecordingSubmissionService(
      uploadDelay: const Duration(milliseconds: 10),
    );
    final RecordMultiplePhotoSubmissionCoordinator coordinator =
        RecordMultiplePhotoSubmissionCoordinator(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionSession session = _sessionFor(photos);
    final RecordSubmissionDraft draft = _draftFor(photos, session);
    int notificationCount = 0;

    final List<String> failedDetails = await coordinator.submit(
      idToken: 'id-token',
      submissionDraft: draft,
      photos: photos,
      session: session,
      onSessionChanged: () {
        notificationCount += 1;
      },
      onAuthenticationRequired: (_) {
        fail('認証更新は要求されない');
      },
    );

    expect(failedDetails, isEmpty);
    expect(service.beginRequestIds, <String>['begin-request']);
    expect(service.finalizeRequestIds, <String>['finalize-request']);
    expect(service.uploadCallCount.length, 5);
    expect(service.uploadCallCount.values, everyElement(1));
    expect(service.maxConcurrentUploadCount, 4);
    expect(service.completedCountAtUploadStart['photo-5'], 4);
    expect(service.events.first, 'begin');
    expect(service.events.last, 'finalize');
    expect(session.beginRecordResult, isNotNull);
    expect(session.finalizeRecordResult, isNotNull);
    expect(session.phase, RecordSubmissionPhase.finalizing);
    expect(session.currentUploadingPhotoId, isNull);
    expect(session.countPhotosWithStatus(RecordPhotoUploadStatus.uploaded), 5);
    expect(session.lastPreparationDuration, isNotNull);
    expect(session.lastPhotoUploadDuration, isNotNull);
    expect(session.lastFinalizeDuration, isNotNull);
    expect(notificationCount, greaterThanOrEqualTo(4));
  });

  test('再送時はbegin済みと送信済み写真を飛ばし失敗写真だけ送る', () async {
    final List<RecordDraftPhoto> photos = _photos(2);
    final _RecordingSubmissionService service = _RecordingSubmissionService();
    final RecordMultiplePhotoSubmissionCoordinator coordinator =
        RecordMultiplePhotoSubmissionCoordinator(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionSession session = _sessionFor(photos)
      ..beginRecordResult = const BeginRecordResult(
        buildingId: 'building-1',
        visitId: 'visit-1',
        expectedPhotoCount: 2,
        buildingCreated: true,
        visitCreated: true,
        reused: false,
      )
      ..applyPhotoUploadResult(
        photoId: 'photo-1',
        result: _uploadResult('photo-1', displayOrder: 1),
      )
      ..photoUploadStatuses['photo-2'] = RecordPhotoUploadStatus.pending;
    final RecordSubmissionDraft draft = _draftFor(photos, session);

    final List<String> failedDetails = await coordinator.submit(
      idToken: 'id-token',
      submissionDraft: draft,
      photos: photos,
      session: session,
      onSessionChanged: () {},
      onAuthenticationRequired: (_) {
        fail('認証更新は要求されない');
      },
    );

    expect(failedDetails, isEmpty);
    expect(service.beginRequestIds, isEmpty);
    expect(service.uploadCallCount, <String, int>{'photo-2': 1});
    expect(service.uploadRequestIds['photo-2'], <String>['request-photo-2']);
    expect(service.finalizeRequestIds, <String>['finalize-request']);
    expect(session.countPhotosWithStatus(RecordPhotoUploadStatus.uploaded), 2);
  });

  test('wave内の1件が失敗したら成功結果を保持し次waveと確定を止める', () async {
    final List<RecordDraftPhoto> photos = _photos(5);
    final _RecordingSubmissionService service = _RecordingSubmissionService(
      failingPhotoIds: <String>{'photo-2'},
    );
    final RecordMultiplePhotoSubmissionCoordinator coordinator =
        RecordMultiplePhotoSubmissionCoordinator(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionSession session = _sessionFor(photos);
    final RecordSubmissionDraft draft = _draftFor(photos, session);

    final List<String> failedDetails = await coordinator.submit(
      idToken: 'id-token',
      submissionDraft: draft,
      photos: photos,
      session: session,
      onSessionChanged: () {},
      onAuthenticationRequired: (_) {
        fail('認証更新は要求されない');
      },
    );

    expect(failedDetails, <String>['photo-2.jpg: テスト用の送信失敗']);
    expect(service.beginRequestIds, hasLength(1));
    expect(
      service.uploadCallCount.keys,
      unorderedEquals(<String>['photo-1', 'photo-2', 'photo-3', 'photo-4']),
    );
    expect(service.uploadCallCount.containsKey('photo-5'), isFalse);
    expect(service.finalizeRequestIds, isEmpty);
    expect(session.photoStatus('photo-1'), RecordPhotoUploadStatus.uploaded);
    expect(session.photoStatus('photo-2'), RecordPhotoUploadStatus.failed);
    expect(session.photoStatus('photo-3'), RecordPhotoUploadStatus.uploaded);
    expect(session.photoStatus('photo-4'), RecordPhotoUploadStatus.uploaded);
    expect(session.photoStatus('photo-5'), RecordPhotoUploadStatus.pending);
    expect(session.finalizeRecordResult, isNull);
    expect(session.lastPhotoUploadDuration, isNotNull);
  });

  test('AUTH_REQUIREDをController用callbackへ通知し確定を止める', () async {
    final List<RecordDraftPhoto> photos = _photos(2);
    final _RecordingSubmissionService service = _RecordingSubmissionService(
      authenticationRequiredPhotoIds: <String>{'photo-1'},
    );
    final RecordMultiplePhotoSubmissionCoordinator coordinator =
        RecordMultiplePhotoSubmissionCoordinator(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionSession session = _sessionFor(photos);
    final RecordSubmissionDraft draft = _draftFor(photos, session);
    final List<String> failedTokens = <String>[];

    final List<String> failedDetails = await coordinator.submit(
      idToken: 'expired-token',
      submissionDraft: draft,
      photos: photos,
      session: session,
      onSessionChanged: () {},
      onAuthenticationRequired: (String token) {
        failedTokens.add(token);
      },
    );

    expect(failedDetails, <String>['photo-1.jpg: 認証期限切れ']);
    expect(failedTokens, <String>['expired-token']);
    expect(session.photoStatus('photo-1'), RecordPhotoUploadStatus.failed);
    expect(session.photoStatus('photo-2'), RecordPhotoUploadStatus.uploaded);
    expect(service.finalizeRequestIds, isEmpty);
  });

  test('全写真送信済みなら同じrequestIdで確定通信だけを行う', () async {
    final List<RecordDraftPhoto> photos = _photos(2);
    final _RecordingSubmissionService service = _RecordingSubmissionService();
    final RecordMultiplePhotoSubmissionCoordinator coordinator =
        RecordMultiplePhotoSubmissionCoordinator(
          recordSubmissionApiService: service,
        );
    final RecordSubmissionSession session = _sessionFor(photos)
      ..beginRecordResult = const BeginRecordResult(
        buildingId: 'building-1',
        visitId: 'visit-1',
        expectedPhotoCount: 2,
        buildingCreated: true,
        visitCreated: true,
        reused: false,
      )
      ..applyPhotoUploadResult(
        photoId: 'photo-1',
        result: _uploadResult('photo-1', displayOrder: 1),
      )
      ..applyPhotoUploadResult(
        photoId: 'photo-2',
        result: _uploadResult('photo-2', displayOrder: 2),
      );
    final RecordSubmissionDraft draft = _draftFor(photos, session);

    final List<String> failedDetails = await coordinator.submit(
      idToken: 'id-token',
      submissionDraft: draft,
      photos: photos,
      session: session,
      onSessionChanged: () {},
      onAuthenticationRequired: (_) {
        fail('認証更新は要求されない');
      },
    );

    expect(failedDetails, isEmpty);
    expect(service.beginRequestIds, isEmpty);
    expect(service.uploadCallCount, isEmpty);
    expect(service.finalizeRequestIds, <String>['finalize-request']);
    expect(session.finalizeRecordResult, isNotNull);
  });
}

List<RecordDraftPhoto> _photos(int count) {
  return List<RecordDraftPhoto>.generate(count, (int index) {
    final int number = index + 1;
    return RecordDraftPhoto(
      photoId: 'photo-$number',
      fileName: 'photo-$number.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[number, number + 1]),
    );
  }, growable: false);
}

RecordSubmissionSession _sessionFor(List<RecordDraftPhoto> photos) {
  final RecordSubmissionSession session = RecordSubmissionSession()
    ..beginRequestId = 'begin-request'
    ..finalizeRequestId = 'finalize-request'
    ..buildingId = 'building-1'
    ..visitId = 'visit-1'
    ..visitedAt = DateTime.parse('2026-08-27T10:00:00+09:00');

  for (final RecordDraftPhoto photo in photos) {
    session.photoRequestIds[photo.photoId] = 'request-${photo.photoId}';
    session.photoUploadStatuses[photo.photoId] =
        RecordPhotoUploadStatus.pending;
  }
  return session;
}

RecordSubmissionDraft _draftFor(
  List<RecordDraftPhoto> photos,
  RecordSubmissionSession session,
) {
  return RecordSubmissionDraftBuilder.build(
    isNewBuilding: true,
    newBuildingName: '複数写真テスト建物',
    newDesignTagIds: const <String>['design-1'],
    newSalesTagIds: const <String>['sales-1'],
    newConstructionTagIds: const <String>['construction-1'],
    pendingExistingDesignTagIds: const <String>[],
    pendingExistingSalesTagIds: const <String>[],
    pendingExistingConstructionTagIds: const <String>[],
    buildingId: session.buildingId!,
    visitId: session.visitId!,
    visitedAt: session.visitedAt!,
    triggerTagIds: const <String>['trigger-1'],
    impression: 'Coordinatorテスト',
    location: RecordDraftLocation(
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 8.4,
      source: RecordLocationSource.gps,
      capturedAt: DateTime.parse('2026-08-27T10:00:00+09:00'),
    ),
    expectedPhotoCount: photos.length,
  );
}

UploadRecordPhotoResult _uploadResult(
  String photoId, {
  required int displayOrder,
}) {
  return UploadRecordPhotoResult(
    photoId: photoId,
    storageFileId: 'storage-$photoId',
    byteSize: 2,
    displayOrder: displayOrder,
    reused: false,
    buildingId: 'building-1',
    visitId: 'visit-1',
  );
}

class _RecordingSubmissionService implements RecordSubmissionApiService {
  _RecordingSubmissionService({
    this.uploadDelay = Duration.zero,
    Set<String> failingPhotoIds = const <String>{},
    Set<String> authenticationRequiredPhotoIds = const <String>{},
  }) : _failingPhotoIds = <String>{...failingPhotoIds},
       _authenticationRequiredPhotoIds = <String>{
         ...authenticationRequiredPhotoIds,
       };

  final Duration uploadDelay;
  final Set<String> _failingPhotoIds;
  final Set<String> _authenticationRequiredPhotoIds;
  final List<String> beginRequestIds = <String>[];
  final List<String> finalizeRequestIds = <String>[];
  final Map<String, int> uploadCallCount = <String, int>{};
  final Map<String, List<String>> uploadRequestIds = <String, List<String>>{};
  final Map<String, int> completedCountAtUploadStart = <String, int>{};
  final List<String> events = <String>[];
  int currentConcurrentUploadCount = 0;
  int maxConcurrentUploadCount = 0;
  int completedUploadCount = 0;

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
    events.add('begin');
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
    completedCountAtUploadStart[photoId] = completedUploadCount;
    currentConcurrentUploadCount += 1;
    if (currentConcurrentUploadCount > maxConcurrentUploadCount) {
      maxConcurrentUploadCount = currentConcurrentUploadCount;
    }
    events.add('upload-start-$photoId');

    try {
      if (uploadDelay != Duration.zero) {
        await Future<void>.delayed(uploadDelay);
      }
      if (_authenticationRequiredPhotoIds.contains(photoId)) {
        throw const RecordSubmissionApiException(
          '認証期限切れ',
          errorCode: 'AUTH_REQUIRED',
        );
      }
      if (_failingPhotoIds.contains(photoId)) {
        throw const RecordSubmissionApiException('テスト用の送信失敗');
      }

      completedUploadCount += 1;
      events.add('upload-end-$photoId');
      return UploadRecordPhotoResult(
        photoId: photoId,
        storageFileId: 'storage-$photoId',
        byteSize: bytes.length,
        displayOrder: displayOrder,
        reused: false,
        buildingId: buildingId,
        visitId: visitId,
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
    events.add('finalize');
    return FinalizeRecordResult(
      buildingId: buildingId,
      visitId: visitId,
      photoCount: completedUploadCount,
      status: 'completed',
      reused: false,
    );
  }

  @override
  void close() {}
}
