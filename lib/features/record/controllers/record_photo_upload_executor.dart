import '../../../core/config/app_config.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/models/record_submission_result.dart';
import '../../../data/services/record_submission_api_service.dart';
import '../domain/record_submission_draft_builder.dart';

/// 複数写真保存で、写真1枚分のAPI呼び出しと例外の結果化を担当する。
///
/// waveの順序、並列数、再送判断、送信状態の更新は
/// `RecordMultiplePhotoSubmissionCoordinator`が担当する。
class RecordPhotoUploadExecutor {
  const RecordPhotoUploadExecutor({
    required RecordSubmissionApiService recordSubmissionApiService,
  }) : _recordSubmissionApiService = recordSubmissionApiService;

  final RecordSubmissionApiService _recordSubmissionApiService;

  Future<RecordPhotoUploadAttempt> upload({
    required String requestId,
    required String idToken,
    required String buildingId,
    required String visitId,
    required RecordSubmissionDraft submissionDraft,
    required RecordDraftPhoto photo,
    required int displayOrder,
  }) async {
    try {
      final UploadRecordPhotoResult result = await _recordSubmissionApiService
          .uploadPhoto(
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
            displayOrder: displayOrder,
          );
      return RecordPhotoUploadAttempt.success(photo: photo, result: result);
    } on RecordSubmissionApiException catch (error) {
      return RecordPhotoUploadAttempt.failure(
        photo: photo,
        errorMessage: error.message,
        errorCode: error.errorCode,
      );
    } catch (_) {
      return RecordPhotoUploadAttempt.failure(
        photo: photo,
        errorMessage: '不明なエラー',
      );
    }
  }
}

/// 写真1枚の送信結果を、例外を投げずにControllerへ返すための値。
class RecordPhotoUploadAttempt {
  const RecordPhotoUploadAttempt._({
    required this.photo,
    required this.result,
    required this.errorMessage,
    required this.errorCode,
  });

  factory RecordPhotoUploadAttempt.success({
    required RecordDraftPhoto photo,
    required UploadRecordPhotoResult result,
  }) {
    return RecordPhotoUploadAttempt._(
      photo: photo,
      result: result,
      errorMessage: null,
      errorCode: null,
    );
  }

  factory RecordPhotoUploadAttempt.failure({
    required RecordDraftPhoto photo,
    required String errorMessage,
    String? errorCode,
  }) {
    return RecordPhotoUploadAttempt._(
      photo: photo,
      result: null,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }

  final RecordDraftPhoto photo;
  final UploadRecordPhotoResult? result;
  final String? errorMessage;
  final String? errorCode;

  bool get authenticationRequired => errorCode == 'AUTH_REQUIRED';
}
