import '../../../core/config/app_config.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/models/record_submission_result.dart';
import '../../../data/services/record_submission_api_service.dart';
import '../domain/record_submission_draft_builder.dart';

/// 写真1枚だけを、建物・訪問の準備と記録確定を含む1通信で保存する。
///
/// 画面状態、再送判断、requestIdの保持、送信時間の計測は
/// `RecordDraftController`が引き続き担当する。
class RecordSinglePhotoSubmissionExecutor {
  const RecordSinglePhotoSubmissionExecutor({
    required RecordSubmissionApiService recordSubmissionApiService,
  }) : _recordSubmissionApiService = recordSubmissionApiService;

  final RecordSubmissionApiService _recordSubmissionApiService;

  Future<RecordSinglePhotoSubmissionAttempt> submit({
    required String requestId,
    required String beginRequestId,
    required String idToken,
    required String buildingId,
    required String visitId,
    required RecordSubmissionDraft submissionDraft,
    required RecordDraftPhoto photo,
    required bool includeRecordPreparation,
  }) async {
    try {
      final UploadRecordPhotoResult uploadResult =
          await _recordSubmissionApiService.uploadPhoto(
            requestId: requestId,
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingId: buildingId,
            visitId: visitId,
            photoId: photo.photoId,
            fileName: photo.fileName,
            mimeType: photo.mimeType,
            bytes: photo.bytes,
            takenAt: submissionDraft.visitedAt,
            latitude: submissionDraft.location.latitude,
            longitude: submissionDraft.location.longitude,
            accuracyM: submissionDraft.location.accuracyM,
            locationSource: submissionDraft.location.source.apiValue,
            displayOrder: 1,
            recordPreparation: includeRecordPreparation
                ? submissionDraft.toRecordPreparationPayload(
                    requestId: beginRequestId,
                  )
                : null,
            finalizeAfterUpload: true,
          );

      final String resolvedBuildingId = uploadResult.buildingId ?? buildingId;
      final String resolvedVisitId = uploadResult.visitId ?? visitId;
      final BeginRecordResult beginRecordResult = BeginRecordResult(
        buildingId: resolvedBuildingId,
        visitId: resolvedVisitId,
        expectedPhotoCount: 1,
        buildingCreated: uploadResult.buildingCreated,
        visitCreated: uploadResult.visitCreated,
        reused: uploadResult.reused,
      );
      final FinalizeRecordResult? finalizeRecordResult =
          uploadResult.recordCompleted
          ? FinalizeRecordResult(
              buildingId: resolvedBuildingId,
              visitId: resolvedVisitId,
              photoCount: uploadResult.photoCount ?? 1,
              status: 'completed',
              reused: uploadResult.reused,
            )
          : null;

      return RecordSinglePhotoSubmissionAttempt.success(
        uploadResult: uploadResult,
        beginRecordResult: beginRecordResult,
        finalizeRecordResult: finalizeRecordResult,
      );
    } on RecordSubmissionApiException catch (error) {
      return RecordSinglePhotoSubmissionAttempt.failure(
        errorMessage: error.message,
        errorCode: error.errorCode,
      );
    } catch (_) {
      return const RecordSinglePhotoSubmissionAttempt.failure(
        errorMessage: '不明なエラー',
      );
    }
  }
}

/// 写真1枚の一括保存結果を、例外を投げずにControllerへ返す値。
class RecordSinglePhotoSubmissionAttempt {
  const RecordSinglePhotoSubmissionAttempt._({
    required this.uploadResult,
    required this.beginRecordResult,
    required this.finalizeRecordResult,
    required this.errorMessage,
    required this.errorCode,
  });

  const RecordSinglePhotoSubmissionAttempt.failure({
    required String errorMessage,
    String? errorCode,
  }) : this._(
         uploadResult: null,
         beginRecordResult: null,
         finalizeRecordResult: null,
         errorMessage: errorMessage,
         errorCode: errorCode,
       );

  factory RecordSinglePhotoSubmissionAttempt.success({
    required UploadRecordPhotoResult uploadResult,
    required BeginRecordResult beginRecordResult,
    required FinalizeRecordResult? finalizeRecordResult,
  }) {
    return RecordSinglePhotoSubmissionAttempt._(
      uploadResult: uploadResult,
      beginRecordResult: beginRecordResult,
      finalizeRecordResult: finalizeRecordResult,
      errorMessage: null,
      errorCode: null,
    );
  }

  final UploadRecordPhotoResult? uploadResult;
  final BeginRecordResult? beginRecordResult;
  final FinalizeRecordResult? finalizeRecordResult;
  final String? errorMessage;
  final String? errorCode;

  bool get authenticationRequired => errorCode == 'AUTH_REQUIRED';
}
