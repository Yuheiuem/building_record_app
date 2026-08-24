var PHOTO_THUMBNAIL_MAX_BYTES_ = 512 * 1024;
var PHOTO_THUMBNAIL_MAX_FALLBACK_BYTES_ = 5 * 1024 * 1024;
var PHOTO_THUMBNAIL_ALLOWED_MIME_TYPES_ = {
  'image/jpeg': true,
  'image/png': true
};

/**
 * PhotosシートのthumbnailFileIdを優先し、ギャラリー表示用画像を返す。
 * 既存写真などthumbnailFileIdが空の場合は元画像へフォールバックする。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetPhotoThumbnailData(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var photoId = getBuildingDetailRequiredId_(payload, 'photoId');

  return createApiResponse(
    true,
    requestId,
    getPhotoThumbnailResponseData_(photoId),
    null,
    null
  );
}

/**
 * 1枚分のサムネイル応答データを作る。
 * 代表写真の一括取得でも同じ検証を再利用する。
 *
 * @param {string} photoId
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet=} spreadsheet
 * @param {Object=} preloadedPhotoRecord
 * @param {boolean=} allowDeleted
 * @return {Object}
 */
function getPhotoThumbnailResponseData_(
  photoId,
  spreadsheet,
  preloadedPhotoRecord,
  allowDeleted
) {
  var dataSpreadsheet = spreadsheet || getDataSpreadsheet_();
  var photoRecord = preloadedPhotoRecord || findBuildingDetailSheetRecord_(
    dataSpreadsheet,
    'Photos',
    'photoId',
    photoId
  );

  if (
    photoRecord === null ||
    (sheetBoolean_(photoRecord.isDeleted) && allowDeleted !== true)
  ) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }

  var buildingId = optionalSheetString_(photoRecord.buildingId);
  if (buildingId === null) {
    throw createApiError_('INTERNAL_ERROR', '写真にbuildingIdがありません。');
  }

  var thumbnailFileId = optionalSheetString_(photoRecord.thumbnailFileId);
  var file;
  var source;
  var maxBytes;

  if (thumbnailFileId !== null) {
    try {
      file = getPhotoThumbnailDriveFile_(thumbnailFileId);
      var thumbnailFolder = getRecordBuildingThumbnailFolder_(
        buildingId,
        false
      );
      if (isBuildingDetailFileInFolder_(file, thumbnailFolder.getId())) {
        source = 'thumbnail';
        maxBytes = PHOTO_THUMBNAIL_MAX_BYTES_;
      } else {
        file = null;
      }
    } catch (ignoreThumbnailError) {
      file = null;
    }
  }

  if (!file) {
    var storageProvider = optionalSheetString_(photoRecord.storageProvider);
    var storageFileId = optionalSheetString_(photoRecord.storageFileId);
    if (storageProvider !== 'google_drive' || storageFileId === null) {
      throw createApiError_('NOT_FOUND', '写真の保存先を確認できませんでした。');
    }

    file = getPhotoThumbnailDriveFile_(storageFileId);
    var building = findBuildingDetailBuilding_(dataSpreadsheet, buildingId);
    var expectedFolderId = optionalSheetString_(building.driveFolderId);
    if (
      expectedFolderId === null ||
      !isBuildingDetailFileInFolder_(file, expectedFolderId)
    ) {
      throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
    }
    source = 'original_fallback';
    maxBytes = PHOTO_THUMBNAIL_MAX_FALLBACK_BYTES_;
  }

  var mimeType = file.getMimeType();
  if (!PHOTO_THUMBNAIL_ALLOWED_MIME_TYPES_[mimeType]) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '保存ファイルが対応画像形式ではありません。'
    );
  }

  var bytes = file.getBlob().getBytes();
  if (bytes.length > maxBytes) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'ギャラリー画像が表示上限を超えています。'
    );
  }

  return {
    photoId: photoId,
    fileName: file.getName(),
    mimeType: mimeType,
    byteSize: bytes.length,
    base64Data: Utilities.base64Encode(bytes),
    source: source,
    stage: '5-4A.1'
  };
}

/**
 * Driveファイルを安全に取得する。
 *
 * @param {string} fileId
 * @return {GoogleAppsScript.Drive.File}
 */
function getPhotoThumbnailDriveFile_(fileId) {
  var file;
  try {
    file = DriveApp.getFileById(fileId);
  } catch (error) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }
  if (file.isTrashed()) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }
  return file;
}

/**
 * 既存の最初の写真を使い、サムネイル取得を確認する。
 * thumbnailFileIdがない写真は元画像フォールバックで成功する。
 */
function testGetPhotoThumbnailData() {
  setupDataSpreadsheet();
  var spreadsheet = getDataSpreadsheet_();
  var photoRows = readSheetObjects_(spreadsheet, 'Photos')
    .filter(function(row) {
      return !sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.photoId) !== null;
    });

  if (photoRows.length === 0) {
    console.log('確認対象の写真がありません。先に記録を1件保存してください。');
    return;
  }

  var authContext = {
    subject: 'apps-script-editor-test',
    email: 'editor-test@example.com'
  };
  var response = handleGetPhotoThumbnailData(
    'apps-script-editor-thumbnail-data-test',
    { photoId: optionalSheetString_(photoRows[0].photoId) },
    authContext
  );
  var result = JSON.parse(response.getContent());
  if (result.data && result.data.base64Data) {
    result.data.base64Length = result.data.base64Data.length;
    delete result.data.base64Data;
  }
  console.log(JSON.stringify(result));
}
