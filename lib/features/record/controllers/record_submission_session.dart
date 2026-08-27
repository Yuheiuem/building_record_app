part of 'record_draft_controller.dart';

/// 1回の記録保存と、その失敗後の再送に必要な可変状態をまとめて保持する。
///
/// 送信手順そのものは引き続き[RecordDraftController]が担当し、このクラスは
/// requestId、保存先ID、写真ごとの送信状態、結果、計測値だけを保持する。
class RecordSubmissionSession {
  RecordSubmissionPhase phase = RecordSubmissionPhase.idle;
  String? errorMessage;
  String? errorDetail;
  String? noticeMessage;
  String? operationMessage;
  DateTime? startedAt;
  BeginRecordResult? beginRecordResult;
  FinalizeRecordResult? finalizeRecordResult;
  String? beginRequestId;
  String? finalizeRequestId;
  String? buildingId;
  String? visitId;
  DateTime? visitedAt;
  String? currentUploadingPhotoId;
  final Map<String, String> photoRequestIds = <String, String>{};
  final Map<String, RecordPhotoUploadStatus> photoUploadStatuses =
      <String, RecordPhotoUploadStatus>{};
  final Map<String, UploadRecordPhotoResult> photoUploadResults =
      <String, UploadRecordPhotoResult>{};
  Duration? lastSubmissionDuration;
  Duration? lastPreparationDuration;
  Duration? lastPhotoUploadDuration;
  Duration? lastFinalizeDuration;
  Duration? lastCombinedSaveDuration;

  bool get succeeded => phase == RecordSubmissionPhase.succeeded;

  bool get isSubmitting =>
      phase == RecordSubmissionPhase.starting ||
      phase == RecordSubmissionPhase.uploading ||
      phase == RecordSubmissionPhase.finalizing;

  bool get isDraftLocked => beginRequestId != null || isSubmitting;

  int countPhotosWithStatus(RecordPhotoUploadStatus status) {
    return photoUploadStatuses.values
        .where((RecordPhotoUploadStatus value) => value == status)
        .length;
  }

  RecordPhotoUploadStatus photoStatus(String photoId) {
    return photoUploadStatuses[photoId] ?? RecordPhotoUploadStatus.pending;
  }

  UploadRecordPhotoResult? photoResult(String photoId) {
    return photoUploadResults[photoId];
  }

  double progressForPhotoCount(int photoCount) {
    if (photoCount <= 0) {
      return 0;
    }
    return countPhotosWithStatus(RecordPhotoUploadStatus.uploaded) / photoCount;
  }

  /// 保存成功した写真の結果を、再送に使うセッション状態へ反映する。
  void applyPhotoUploadResult({
    required String photoId,
    required UploadRecordPhotoResult result,
  }) {
    buildingId = result.buildingId ?? buildingId;
    visitId = result.visitId ?? visitId;
    photoUploadResults[photoId] = result;
    photoUploadStatuses[photoId] = RecordPhotoUploadStatus.uploaded;
  }

  /// 保存完了後に新しい下書きを始めるため、送信関連の状態だけを初期化する。
  void reset() {
    phase = RecordSubmissionPhase.idle;
    errorMessage = null;
    errorDetail = null;
    noticeMessage = null;
    operationMessage = null;
    startedAt = null;
    beginRecordResult = null;
    finalizeRecordResult = null;
    beginRequestId = null;
    finalizeRequestId = null;
    buildingId = null;
    visitId = null;
    visitedAt = null;
    currentUploadingPhotoId = null;
    photoRequestIds.clear();
    photoUploadStatuses.clear();
    photoUploadResults.clear();
    lastSubmissionDuration = null;
    lastPreparationDuration = null;
    lastPhotoUploadDuration = null;
    lastFinalizeDuration = null;
    lastCombinedSaveDuration = null;
  }
}
