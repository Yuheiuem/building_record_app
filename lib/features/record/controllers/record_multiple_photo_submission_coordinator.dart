part of 'record_draft_controller.dart';

/// 複数写真保存のbegin、4件単位のwave送信、finalizeを調整する。
///
/// Controllerの公開API、最終的な成功・失敗表示、Bootstrap再取得は
/// `RecordDraftController`が引き続き担当する。
class RecordMultiplePhotoSubmissionCoordinator {
  RecordMultiplePhotoSubmissionCoordinator({
    required RecordSubmissionApiService recordSubmissionApiService,
    RecordPhotoUploadExecutor? photoUploadExecutor,
  }) : _recordSubmissionApiService = recordSubmissionApiService,
       _photoUploadExecutor =
           photoUploadExecutor ??
           RecordPhotoUploadExecutor(
             recordSubmissionApiService: recordSubmissionApiService,
           );

  static const int _photoWaveSize = 4;

  final RecordSubmissionApiService _recordSubmissionApiService;
  final RecordPhotoUploadExecutor _photoUploadExecutor;

  Future<List<String>> submit({
    required String idToken,
    required RecordSubmissionDraft submissionDraft,
    required List<RecordDraftPhoto> photos,
    required RecordSubmissionSession session,
    required VoidCallback onSessionChanged,
    required ValueChanged<String> onAuthenticationRequired,
  }) async {
    await _beginRecordIfNeeded(
      idToken: idToken,
      submissionDraft: submissionDraft,
      session: session,
      onSessionChanged: onSessionChanged,
    );

    final List<String> failedDetails = await _uploadPendingPhotos(
      idToken: idToken,
      submissionDraft: submissionDraft,
      photos: photos,
      session: session,
      onSessionChanged: onSessionChanged,
      onAuthenticationRequired: onAuthenticationRequired,
    );
    if (failedDetails.isNotEmpty) {
      return failedDetails;
    }

    await _finalizeRecordIfNeeded(
      idToken: idToken,
      session: session,
      onSessionChanged: onSessionChanged,
    );
    return failedDetails;
  }

  Future<void> _beginRecordIfNeeded({
    required String idToken,
    required RecordSubmissionDraft submissionDraft,
    required RecordSubmissionSession session,
    required VoidCallback onSessionChanged,
  }) async {
    if (session.beginRecordResult != null) {
      return;
    }

    session.phase = RecordSubmissionPhase.starting;
    session.operationMessage = '建物・訪問データを送信しています。';
    onSessionChanged();

    final Stopwatch preparationStopwatch = Stopwatch()..start();
    try {
      final BeginRecordResult beginResult = await _recordSubmissionApiService
          .beginRecord(
            requestId: session.beginRequestId!,
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingMode: submissionDraft.buildingMode,
            buildingId: submissionDraft.buildingId,
            visitId: submissionDraft.visitId,
            buildingName: submissionDraft.buildingName,
            designTagIds: submissionDraft.designTagIds,
            salesTagIds: submissionDraft.salesTagIds,
            constructionTagIds: submissionDraft.constructionTagIds,
            visitedAt: submissionDraft.visitedAt,
            triggerTagIds: submissionDraft.triggerTagIds,
            impression: submissionDraft.impression,
            latitude: submissionDraft.location.latitude,
            longitude: submissionDraft.location.longitude,
            accuracyM: submissionDraft.location.accuracyM,
            locationSource: submissionDraft.location.source.apiValue,
            expectedPhotoCount: submissionDraft.expectedPhotoCount,
          );
      session.beginRecordResult = beginResult;
      session.buildingId = beginResult.buildingId;
      session.visitId = beginResult.visitId;
    } finally {
      preparationStopwatch.stop();
      session.lastPreparationDuration = preparationStopwatch.elapsed;
    }
  }

  Future<List<String>> _uploadPendingPhotos({
    required String idToken,
    required RecordSubmissionDraft submissionDraft,
    required List<RecordDraftPhoto> photos,
    required RecordSubmissionSession session,
    required VoidCallback onSessionChanged,
    required ValueChanged<String> onAuthenticationRequired,
  }) async {
    final List<RecordDraftPhoto> pendingPhotos = photos
        .where(
          (RecordDraftPhoto photo) =>
              session.photoStatus(photo.photoId) !=
              RecordPhotoUploadStatus.uploaded,
        )
        .toList(growable: false);
    final List<String> failedDetails = <String>[];

    if (pendingPhotos.isEmpty) {
      return failedDetails;
    }

    final Stopwatch photoUploadStopwatch = Stopwatch()..start();
    try {
      for (
        int offset = 0;
        offset < pendingPhotos.length;
        offset += _photoWaveSize
      ) {
        final int end = (offset + _photoWaveSize)
            .clamp(0, pendingPhotos.length)
            .toInt();
        final List<RecordDraftPhoto> wave = pendingPhotos.sublist(offset, end);

        session.phase = RecordSubmissionPhase.uploading;
        final int completedBeforeWave = session.countPhotosWithStatus(
          RecordPhotoUploadStatus.uploaded,
        );
        session.operationMessage =
            '写真を送信用データへ変換して送信しています。'
            ' 完了 $completedBeforeWave/${photos.length}枚、'
            '今回 ${wave.length}枚を処理中です。';
        session.currentUploadingPhotoId = wave.first.photoId;
        for (final RecordDraftPhoto photo in wave) {
          session.photoUploadStatuses[photo.photoId] =
              RecordPhotoUploadStatus.uploading;
        }
        onSessionChanged();

        final List<RecordPhotoUploadAttempt> attempts = await Future.wait(
          wave.map((RecordDraftPhoto photo) {
            return _photoUploadExecutor.upload(
              requestId: session.photoRequestIds[photo.photoId]!,
              idToken: idToken,
              buildingId: session.buildingId!,
              visitId: session.visitId!,
              submissionDraft: submissionDraft,
              photo: photo,
              displayOrder: photos.indexOf(photo) + 1,
            );
          }),
        );

        for (final RecordPhotoUploadAttempt attempt in attempts) {
          final UploadRecordPhotoResult? result = attempt.result;
          if (result != null) {
            session.applyPhotoUploadResult(
              photoId: attempt.photo.photoId,
              result: result,
            );
            continue;
          }

          session.photoUploadStatuses[attempt.photo.photoId] =
              RecordPhotoUploadStatus.failed;
          if (attempt.authenticationRequired) {
            onAuthenticationRequired(idToken);
          }
          failedDetails.add(
            '${attempt.photo.fileName}: '
            '${attempt.errorMessage ?? '不明なエラー'}',
          );
        }
        onSessionChanged();

        if (failedDetails.isNotEmpty) {
          session.operationMessage = '一部の写真送信に失敗しました。失敗分だけ再送できます。';
          return failedDetails;
        }
      }
    } finally {
      photoUploadStopwatch.stop();
      session.lastPhotoUploadDuration = photoUploadStopwatch.elapsed;
    }

    return failedDetails;
  }

  Future<void> _finalizeRecordIfNeeded({
    required String idToken,
    required RecordSubmissionSession session,
    required VoidCallback onSessionChanged,
  }) async {
    if (session.finalizeRecordResult != null) {
      return;
    }

    session.phase = RecordSubmissionPhase.finalizing;
    session.operationMessage = '保存した写真を確認して記録を確定しています。';
    session.currentUploadingPhotoId = null;
    onSessionChanged();

    final Stopwatch finalizeStopwatch = Stopwatch()..start();
    try {
      session.finalizeRecordResult = await _recordSubmissionApiService
          .finalizeRecord(
            requestId: session.finalizeRequestId!,
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingId: session.buildingId!,
            visitId: session.visitId!,
          );
    } finally {
      finalizeStopwatch.stop();
      session.lastFinalizeDuration = finalizeStopwatch.elapsed;
    }
  }
}
