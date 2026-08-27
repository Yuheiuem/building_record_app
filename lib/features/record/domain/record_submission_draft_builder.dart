import 'package:flutter/foundation.dart';

import '../../../data/models/record_draft_location.dart';
import '../../../data/services/record_submission_api_service.dart';

/// 記録送信前の入力検証と、送信に使う不変データの組み立てを担当する。
///
/// Controllerの状態やServiceを保持せず、同じ入力には同じ結果を返す。
abstract final class RecordSubmissionDraftBuilder {
  static String? validate({
    required bool hasPhotos,
    required bool isNewBuilding,
    required String newBuildingName,
    required bool hasSelectedExistingBuilding,
    required bool hasVisitLocation,
    required String? idToken,
  }) {
    if (!hasPhotos) {
      return '写真を1枚以上選択してください。';
    }

    if (isNewBuilding) {
      final String buildingName = newBuildingName.trim();
      if (buildingName.isEmpty) {
        return '建物名を入力してください。';
      }
      if (buildingName.runes.length > 100) {
        return '建物名は100文字以内で入力してください。';
      }
    } else if (!hasSelectedExistingBuilding) {
      return '登録済みの建物を選択してください。';
    }

    if (!hasVisitLocation) {
      return '位置情報を取得してください。';
    }

    if (idToken == null || idToken.isEmpty) {
      return 'Googleログイン情報を取得できませんでした。';
    }

    return null;
  }

  static RecordSubmissionDraft build({
    required bool isNewBuilding,
    required String newBuildingName,
    required Iterable<String> newDesignTagIds,
    required Iterable<String> newSalesTagIds,
    required Iterable<String> newConstructionTagIds,
    required Iterable<String> pendingExistingDesignTagIds,
    required Iterable<String> pendingExistingSalesTagIds,
    required Iterable<String> pendingExistingConstructionTagIds,
    required String buildingId,
    required String visitId,
    required DateTime visitedAt,
    required Iterable<String> triggerTagIds,
    required String impression,
    required RecordDraftLocation location,
    required int expectedPhotoCount,
  }) {
    return RecordSubmissionDraft._(
      buildingMode: isNewBuilding ? 'new' : 'existing',
      buildingId: buildingId,
      visitId: visitId,
      buildingName: isNewBuilding ? newBuildingName.trim() : null,
      designTagIds: _sortedIds(
        isNewBuilding ? newDesignTagIds : pendingExistingDesignTagIds,
      ),
      salesTagIds: _sortedIds(
        isNewBuilding ? newSalesTagIds : pendingExistingSalesTagIds,
      ),
      constructionTagIds: _sortedIds(
        isNewBuilding
            ? newConstructionTagIds
            : pendingExistingConstructionTagIds,
      ),
      visitedAt: visitedAt,
      triggerTagIds: _sortedIds(triggerTagIds),
      impression: impression.trim(),
      location: location,
      expectedPhotoCount: expectedPhotoCount,
    );
  }

  static List<String> _sortedIds(Iterable<String> ids) {
    final List<String> result = ids.toList()..sort();
    return List<String>.unmodifiable(result);
  }
}

@immutable
class RecordSubmissionDraft {
  const RecordSubmissionDraft._({
    required this.buildingMode,
    required this.buildingId,
    required this.visitId,
    required this.buildingName,
    required this.designTagIds,
    required this.salesTagIds,
    required this.constructionTagIds,
    required this.visitedAt,
    required this.triggerTagIds,
    required this.impression,
    required this.location,
    required this.expectedPhotoCount,
  });

  final String buildingMode;
  final String buildingId;
  final String visitId;
  final String? buildingName;
  final List<String> designTagIds;
  final List<String> salesTagIds;
  final List<String> constructionTagIds;
  final DateTime visitedAt;
  final List<String> triggerTagIds;
  final String impression;
  final RecordDraftLocation location;
  final int expectedPhotoCount;

  RecordPreparationPayload toRecordPreparationPayload({
    required String requestId,
  }) {
    return RecordPreparationPayload(
      requestId: requestId,
      buildingMode: buildingMode,
      buildingId: buildingId,
      visitId: visitId,
      buildingName: buildingName,
      designTagIds: designTagIds,
      salesTagIds: salesTagIds,
      constructionTagIds: constructionTagIds,
      visitedAt: visitedAt,
      triggerTagIds: triggerTagIds,
      impression: impression,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyM: location.accuracyM,
      locationSource: location.source.apiValue,
      expectedPhotoCount: expectedPhotoCount,
    );
  }
}
