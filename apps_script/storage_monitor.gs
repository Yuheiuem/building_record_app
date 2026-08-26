/**
 * Googleアカウントの保存容量と、本アプリが保持している元画像容量を返す。
 * Googleアカウント容量はDrive API v3のstorageQuotaを使用するため、
 * DriveだけでなくGmail・Googleフォト等を含む合計使用量となる。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetStorageUsage(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var about;
  try {
    about = Drive.About.get({
      fields: 'storageQuota(limit,usage,usageInDrive,usageInDriveTrash)'
    });
  } catch (error) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Google Driveの容量情報を取得できませんでした。'
    );
  }

  var quota = about && about.storageQuota ? about.storageQuota : {};
  var spreadsheet = getDataSpreadsheet_();
  var buildings = readSheetObjects_(spreadsheet, 'Buildings');
  var visits = readSheetObjects_(spreadsheet, 'Visits');
  var photos = readSheetObjects_(spreadsheet, 'Photos');
  var hiddenBuildingIds = {};
  var hiddenVisitIds = {};
  buildings.forEach(function(building) {
    var buildingId = optionalSheetString_(building.buildingId);
    if (buildingId !== null && sheetBoolean_(building.isDeleted)) {
      hiddenBuildingIds[buildingId] = true;
    }
  });
  visits.forEach(function(visit) {
    var visitId = optionalSheetString_(visit.visitId);
    if (visitId !== null && sheetBoolean_(visit.isDeleted)) {
      hiddenVisitIds[visitId] = true;
    }
  });

  var originalPhotoBytes = 0;
  var storedPhotoCount = 0;
  var activePhotoCount = 0;
  var hiddenPhotoCount = 0;

  photos.forEach(function(photo) {
    var storageFileId = optionalSheetString_(photo.storageFileId);
    if (storageFileId === null) {
      return;
    }

    var byteSize = optionalSheetNumber_(photo.byteSize);
    if (byteSize !== null && byteSize > 0) {
      originalPhotoBytes += byteSize;
    }
    storedPhotoCount += 1;

    var buildingId = optionalSheetString_(photo.buildingId);
    var visitId = optionalSheetString_(photo.visitId);
    var hidden = sheetBoolean_(photo.isDeleted)
      || (buildingId !== null && hiddenBuildingIds[buildingId] === true)
      || (visitId !== null && hiddenVisitIds[visitId] === true);
    if (hidden) {
      hiddenPhotoCount += 1;
    } else {
      activePhotoCount += 1;
    }
  });

  return createApiResponse(
    true,
    requestId,
    {
      quota: {
        limitBytes: storageQuotaNumber_(quota.limit),
        usageBytes: storageQuotaNumberOrZero_(quota.usage),
        usageInDriveBytes: storageQuotaNumberOrZero_(quota.usageInDrive),
        usageInDriveTrashBytes: storageQuotaNumberOrZero_(
          quota.usageInDriveTrash
        )
      },
      app: {
        originalPhotoBytes: originalPhotoBytes,
        storedPhotoCount: storedPhotoCount,
        activePhotoCount: activePhotoCount,
        hiddenPhotoCount: hiddenPhotoCount
      },
      stage: '5-5.5'
    },
    null,
    null
  );
}

/**
 * storageQuotaの数値文字列をNumberへ変換する。
 * unlimited等で値が存在しない場合はnullを返す。
 *
 * @param {*} value
 * @return {number|null}
 */
function storageQuotaNumber_(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  var result = Number(value);
  if (!isFinite(result) || result < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Google Driveの容量情報を数値として読み取れませんでした。'
    );
  }
  return result;
}

/**
 * storageQuotaの任意値をNumberへ変換する。未設定は0として扱う。
 *
 * @param {*} value
 * @return {number}
 */
function storageQuotaNumberOrZero_(value) {
  var result = storageQuotaNumber_(value);
  return result === null ? 0 : result;
}
