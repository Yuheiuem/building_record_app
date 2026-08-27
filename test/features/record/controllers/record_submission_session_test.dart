import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('初期状態は未送信で下書きをロックしない', () {
    final RecordSubmissionSession session = RecordSubmissionSession();

    expect(session.phase, RecordSubmissionPhase.idle);
    expect(session.succeeded, isFalse);
    expect(session.isSubmitting, isFalse);
    expect(session.isDraftLocked, isFalse);
    expect(
      session.photoStatus('missing-photo'),
      RecordPhotoUploadStatus.pending,
    );
    expect(session.photoResult('missing-photo'), isNull);
    expect(session.progressForPhotoCount(0), 0);
  });

  test('送信状態の件数と進捗を写真ごとに集計する', () {
    final RecordSubmissionSession session = RecordSubmissionSession();
    session.photoUploadStatuses.addAll(<String, RecordPhotoUploadStatus>{
      'photo-uploaded': RecordPhotoUploadStatus.uploaded,
      'photo-uploading': RecordPhotoUploadStatus.uploading,
      'photo-failed': RecordPhotoUploadStatus.failed,
      'photo-pending': RecordPhotoUploadStatus.pending,
    });

    expect(
      session.countPhotosWithStatus(RecordPhotoUploadStatus.uploaded),
      1,
    );
    expect(
      session.countPhotosWithStatus(RecordPhotoUploadStatus.uploading),
      1,
    );
    expect(session.countPhotosWithStatus(RecordPhotoUploadStatus.failed), 1);
    expect(session.countPhotosWithStatus(RecordPhotoUploadStatus.pending), 1);
    expect(session.progressForPhotoCount(4), 0.25);
  });

  test('写真送信結果を保存先ID・結果・uploaded状態へ反映する', () {
    final RecordSubmissionSession session = RecordSubmissionSession()
      ..buildingId = 'building-before'
      ..visitId = 'visit-before';

    const UploadRecordPhotoResult resultWithoutIds = UploadRecordPhotoResult(
      photoId: 'photo-1',
      storageFileId: 'storage-1',
      byteSize: 100,
      displayOrder: 1,
      reused: false,
    );
    session.applyPhotoUploadResult(
      photoId: 'photo-1',
      result: resultWithoutIds,
    );

    expect(session.buildingId, 'building-before');
    expect(session.visitId, 'visit-before');
    expect(session.photoResult('photo-1'), same(resultWithoutIds));
    expect(
      session.photoStatus('photo-1'),
      RecordPhotoUploadStatus.uploaded,
    );

    const UploadRecordPhotoResult resultWithIds = UploadRecordPhotoResult(
      photoId: 'photo-2',
      storageFileId: 'storage-2',
      byteSize: 200,
      displayOrder: 2,
      reused: false,
      buildingId: 'building-after',
      visitId: 'visit-after',
    );
    session.applyPhotoUploadResult(
      photoId: 'photo-2',
      result: resultWithIds,
    );

    expect(session.buildingId, 'building-after');
    expect(session.visitId, 'visit-after');
    expect(session.photoResult('photo-2'), same(resultWithIds));
    expect(
      session.photoStatus('photo-2'),
      RecordPhotoUploadStatus.uploaded,
    );
  });

  test('begin開始後または送信中は下書きをロックする', () {
    final RecordSubmissionSession session = RecordSubmissionSession();

    session.beginRequestId = 'begin-request';
    expect(session.isDraftLocked, isTrue);

    session.reset();
    session.phase = RecordSubmissionPhase.uploading;
    expect(session.isSubmitting, isTrue);
    expect(session.isDraftLocked, isTrue);
  });

  test('resetでrequestId・結果・写真状態・計測値をすべて初期化する', () {
    final RecordSubmissionSession session = RecordSubmissionSession();
    session
      ..phase = RecordSubmissionPhase.succeeded
      ..errorMessage = 'error'
      ..errorDetail = 'detail'
      ..noticeMessage = 'notice'
      ..operationMessage = 'operation'
      ..startedAt = DateTime(2026, 8, 27, 10)
      ..beginRecordResult = const BeginRecordResult(
        buildingId: 'building-1',
        visitId: 'visit-1',
        expectedPhotoCount: 1,
        buildingCreated: true,
        visitCreated: true,
        reused: false,
      )
      ..finalizeRecordResult = const FinalizeRecordResult(
        buildingId: 'building-1',
        visitId: 'visit-1',
        photoCount: 1,
        status: 'completed',
        reused: false,
      )
      ..beginRequestId = 'begin-request'
      ..finalizeRequestId = 'finalize-request'
      ..buildingId = 'building-1'
      ..visitId = 'visit-1'
      ..visitedAt = DateTime(2026, 8, 27, 9)
      ..currentUploadingPhotoId = 'photo-1'
      ..lastSubmissionDuration = const Duration(seconds: 10)
      ..lastPreparationDuration = const Duration(seconds: 2)
      ..lastPhotoUploadDuration = const Duration(seconds: 5)
      ..lastFinalizeDuration = const Duration(seconds: 3)
      ..lastCombinedSaveDuration = const Duration(seconds: 9);
    session.photoRequestIds['photo-1'] = 'photo-request';
    session.photoUploadStatuses['photo-1'] =
        RecordPhotoUploadStatus.uploaded;
    session.photoUploadResults['photo-1'] = const UploadRecordPhotoResult(
      photoId: 'photo-1',
      storageFileId: 'storage-1',
      byteSize: 100,
      displayOrder: 1,
      reused: false,
    );

    session.reset();

    expect(session.phase, RecordSubmissionPhase.idle);
    expect(session.errorMessage, isNull);
    expect(session.errorDetail, isNull);
    expect(session.noticeMessage, isNull);
    expect(session.operationMessage, isNull);
    expect(session.startedAt, isNull);
    expect(session.beginRecordResult, isNull);
    expect(session.finalizeRecordResult, isNull);
    expect(session.beginRequestId, isNull);
    expect(session.finalizeRequestId, isNull);
    expect(session.buildingId, isNull);
    expect(session.visitId, isNull);
    expect(session.visitedAt, isNull);
    expect(session.currentUploadingPhotoId, isNull);
    expect(session.photoRequestIds, isEmpty);
    expect(session.photoUploadStatuses, isEmpty);
    expect(session.photoUploadResults, isEmpty);
    expect(session.lastSubmissionDuration, isNull);
    expect(session.lastPreparationDuration, isNull);
    expect(session.lastPhotoUploadDuration, isNull);
    expect(session.lastFinalizeDuration, isNull);
    expect(session.lastCombinedSaveDuration, isNull);
    expect(session.isDraftLocked, isFalse);
  });
}
