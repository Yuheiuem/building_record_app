var BUILDING_COVER_THUMBNAIL_BATCH_LIMIT_ = 8;

/**
 * 建物の代表写真を更新する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUpdateBuildingCoverPhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeUpdateBuildingCoverPhotoPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var buildingRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Buildings',
      'buildingId',
      normalized.buildingId
    );
    var photoRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    var photoBuildingId = optionalSheetString_(photoRecord.object.buildingId);
    if (photoBuildingId !== normalized.buildingId) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '選択した写真はこの建物の写真ではありません。'
      );
    }

    var definition = findSheetDefinition_('Buildings');
    var coverPhotoIdIndex = definition.headers.indexOf('coverPhotoId');
    var updatedAtIndex = definition.headers.indexOf('updatedAt');
    if (coverPhotoIdIndex < 0 || updatedAtIndex < 0) {
      throw createApiError_(
        'INTERNAL_ERROR',
        'Buildingsシートの代表写真列定義が正しくありません。'
      );
    }

    var values = buildingRecord.values.slice();
    values[coverPhotoIdIndex] = normalized.photoId;
    values[updatedAtIndex] = new Date();
    updateSheetRecord_(
      spreadsheet,
      'Buildings',
      buildingRecord.rowNumber,
      values
    );

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-4A',
        buildingId: normalized.buildingId,
        coverPhotoId: normalized.photoId
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 地図・一覧用の代表写真サムネイルをまとめて返す。
 * 1枚の取得失敗で全体を失敗させず、missingPhotoIdsへ記録する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetCoverPhotoThumbnails(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalized = normalizeGetCoverPhotoThumbnailsPayload_(payload);
  var thumbnails = [];
  var missingPhotoIds = [];
  var spreadsheet = getDataSpreadsheet_();

  normalized.photoIds.forEach(function(photoId) {
    try {
      thumbnails.push(getPhotoThumbnailResponseData_(photoId, spreadsheet));
    } catch (error) {
      missingPhotoIds.push(photoId);
    }
  });

  return createApiResponse(
    true,
    requestId,
    {
      stage: '5-4A',
      thumbnails: thumbnails,
      missingPhotoIds: missingPhotoIds
    },
    null,
    null
  );
}

/**
 * @param {Object} payload
 * @return {{buildingId: string, photoId: string}}
 */
function normalizeUpdateBuildingCoverPhotoPayload_(payload) {
  var safe = requireRecordPayloadObject_(payload);
  return {
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    photoId: requireRecordId_(safe.photoId, 'photoId')
  };
}

/**
 * @param {Object} payload
 * @return {{photoIds: string[]}}
 */
function normalizeGetCoverPhotoThumbnailsPayload_(payload) {
  var safe = requireRecordPayloadObject_(payload);
  if (!Array.isArray(safe.photoIds)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'photoIdsは配列で指定してください。'
    );
  }
  if (safe.photoIds.length > BUILDING_COVER_THUMBNAIL_BATCH_LIMIT_) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '代表写真サムネイルは一度に8枚まで取得できます。'
    );
  }

  var seen = {};
  var photoIds = [];
  safe.photoIds.forEach(function(value) {
    var photoId = requireRecordId_(value, 'photoId');
    if (!seen[photoId]) {
      seen[photoId] = true;
      photoIds.push(photoId);
    }
  });
  return { photoIds: photoIds };
}

/**
 * Apps Scriptエディタで代表写真更新payloadを確認する。
 */
function testNormalizeUpdateBuildingCoverPhotoPayload() {
  var result = normalizeUpdateBuildingCoverPhotoPayload_({
    buildingId: 'building-12345678',
    photoId: 'photo-12345678'
  });
  console.log(JSON.stringify(result));
}

/**
 * Apps Scriptエディタで代表写真サムネイルpayloadを確認する。
 */
function testNormalizeGetCoverPhotoThumbnailsPayload() {
  var result = normalizeGetCoverPhotoThumbnailsPayload_({
    photoIds: ['photo-12345678', 'photo-87654321']
  });
  console.log(JSON.stringify(result));
}
