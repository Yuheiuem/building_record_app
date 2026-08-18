/**
 * 元写真の保存完了後に、ギャラリー用サムネイルだけを別通信で保存する。
 * この処理が失敗しても、すでに完了した建物・訪問・元写真の保存結果には影響しない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUploadPhotoThumbnail(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalized = normalizePhotoThumbnailUploadPayload_(payload);
  var thumbnailBytes = decodeDeferredThumbnailBytes_(normalized);

  var spreadsheet = getDataSpreadsheet_();
  var photoRecord = findSheetRecordById_(
    spreadsheet,
    'Photos',
    'photoId',
    normalized.photoId
  );
  validateDeferredThumbnailPhotoRecord_(photoRecord, normalized);

  var currentThumbnailFileId = optionalSheetString_(
    photoRecord.object.thumbnailFileId
  );
  if (currentThumbnailFileId !== null) {
    return createApiResponse(
      true,
      requestId,
      {
        photoId: normalized.photoId,
        thumbnailFileId: currentThumbnailFileId,
        reused: true,
        stage: '5-4A.4'
      },
      null,
      null
    );
  }

  var thumbnailSave = saveRecordThumbnailSafely_(
    normalized,
    thumbnailBytes,
    false
  );
  if (thumbnailSave.fileId === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      thumbnailSave.warning || 'サムネイルを保存できませんでした。'
    );
  }

  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    photoRecord = findSheetRecordById_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    validateDeferredThumbnailPhotoRecord_(photoRecord, normalized);

    currentThumbnailFileId = optionalSheetString_(
      photoRecord.object.thumbnailFileId
    );
    if (currentThumbnailFileId !== null) {
      if (
        thumbnailSave.created &&
        thumbnailSave.fileId !== currentThumbnailFileId
      ) {
        trashRecordThumbnailFile_(thumbnailSave.fileId);
      }
      return createApiResponse(
        true,
        requestId,
        {
          photoId: normalized.photoId,
          thumbnailFileId: currentThumbnailFileId,
          reused: true,
          stage: '5-4A.4'
        },
        null,
        null
      );
    }

    var values = photoRecord.values.slice();
    values[5] = thumbnailSave.fileId;
    updateSheetRecord_(
      spreadsheet,
      'Photos',
      photoRecord.rowNumber,
      values
    );

    return createApiResponse(
      true,
      requestId,
      {
        photoId: normalized.photoId,
        thumbnailFileId: thumbnailSave.fileId,
        reused: thumbnailSave.reused,
        stage: '5-4A.4'
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * @param {Object} payload
 * @return {{buildingId:string, visitId:string, photoId:string, thumbnailMimeType:string, thumbnailByteSize:number, thumbnailBase64Data:string}}
 */
function normalizePhotoThumbnailUploadPayload_(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイル送信データが正しくありません。'
    );
  }

  var buildingId = getOptionalString(payload.buildingId);
  var visitId = getOptionalString(payload.visitId);
  var photoId = getOptionalString(payload.photoId);
  var mimeType = getOptionalString(payload.thumbnailMimeType);
  var base64Data = getOptionalString(payload.thumbnailBase64Data);
  var byteSize = Number(payload.thumbnailByteSize);

  if (buildingId === null || visitId === null || photoId === null) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '建物・訪問・写真IDがありません。'
    );
  }
  if (mimeType !== RECORD_THUMBNAIL_MIME_TYPE) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイル形式が正しくありません。'
    );
  }
  if (
    !Number.isFinite(byteSize) ||
    Math.floor(byteSize) !== byteSize ||
    byteSize <= 0 ||
    byteSize > RECORD_MAX_THUMBNAIL_BYTES
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイルサイズが正しくありません。'
    );
  }
  if (base64Data === null) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイル画像データがありません。'
    );
  }

  return {
    buildingId: buildingId,
    visitId: visitId,
    photoId: photoId,
    thumbnailMimeType: mimeType,
    thumbnailByteSize: byteSize,
    thumbnailBase64Data: base64Data
  };
}

/**
 * @param {Object} normalized
 * @return {number[]}
 */
function decodeDeferredThumbnailBytes_(normalized) {
  var bytes;
  try {
    bytes = Utilities.base64Decode(normalized.thumbnailBase64Data);
  } catch (error) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイル画像データが正しいBase64ではありません。'
    );
  }
  if (
    bytes.length !== normalized.thumbnailByteSize ||
    bytes.length > RECORD_MAX_THUMBNAIL_BYTES
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'サムネイル画像データのサイズが一致しません。'
    );
  }
  return bytes;
}

/**
 * @param {Object|null} photoRecord
 * @param {Object} normalized
 */
function validateDeferredThumbnailPhotoRecord_(photoRecord, normalized) {
  if (photoRecord === null || sheetBoolean_(photoRecord.object.isDeleted)) {
    throw createApiError_(
      'NOT_FOUND',
      'サムネイルを追加する写真が見つかりませんでした。'
    );
  }
  if (
    String(photoRecord.object.buildingId) !== normalized.buildingId ||
    String(photoRecord.object.visitId) !== normalized.visitId
  ) {
    throw createApiError_(
      'CONFLICT',
      'サムネイルの建物・訪問・写真の対応が一致しません。'
    );
  }
}

/**
 * 段階5-4A.4のサムネイル後送信用payloadを検証する。
 * DriveやSheetsは変更しない。
 */
function testNormalizePhotoThumbnailUploadPayload() {
  var bytes = [1, 2, 3, 4];
  var normalized = normalizePhotoThumbnailUploadPayload_({
    buildingId: 'test-building',
    visitId: 'test-visit',
    photoId: 'test-photo',
    thumbnailMimeType: 'image/jpeg',
    thumbnailByteSize: bytes.length,
    thumbnailBase64Data: Utilities.base64Encode(bytes)
  });
  var decoded = decodeDeferredThumbnailBytes_(normalized);
  if (
    normalized.photoId !== 'test-photo' ||
    decoded.length !== bytes.length
  ) {
    throw new Error('サムネイル後送信用payloadを検証できませんでした。');
  }
  console.log(JSON.stringify({
    buildingId: normalized.buildingId,
    visitId: normalized.visitId,
    photoId: normalized.photoId,
    byteSize: decoded.length
  }));
}
