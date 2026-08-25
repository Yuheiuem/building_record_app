/**
 * 段階5-5.3: 建物の非表示・復元・完全削除。
 *
 * 非表示はBuildings.isDeletedのみを変更し、Visit / Photo / Driveファイルは保持する。
 * 完全削除は建物配下の元画像フォルダとサムネイルフォルダをDriveから永久削除し、
 * Sheets行は監査・ID履歴のため残したまま削除済み状態へ更新する。
 */

/**
 * 復元可能な非表示建物を返す。
 * 完全削除済み（driveFolderIdが空）の建物は一覧へ返さない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetHiddenBuildings(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var spreadsheet = getDataSpreadsheet_();
  var summaries = readSheetObjects_(spreadsheet, 'Buildings')
    .filter(function(row) {
      return sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.driveFolderId) !== null;
    })
    .map(function(row) {
      return getBuildingLifecycleSummary_(spreadsheet, row);
    })
    .sort(function(left, right) {
      return String(left.building.buildingName || '').localeCompare(
        String(right.building.buildingName || ''),
        'ja'
      );
    });

  return createApiResponse(
    true,
    requestId,
    {
      stage: '5-5.3',
      buildings: summaries
    },
    null,
    null
  );
}

/**
 * 完全削除前の影響件数・容量を返す。
 * 有効・非表示のどちらの建物も確認できる。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetBuildingDeletionPreview(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var spreadsheet = getDataSpreadsheet_();
  var buildingRecord = findSheetRecordById_(
    spreadsheet,
    'Buildings',
    'buildingId',
    buildingId
  );
  if (buildingRecord === null) {
    throw createApiError_('NOT_FOUND', '建物が見つかりませんでした。');
  }

  return createApiResponse(
    true,
    requestId,
    {
      stage: '5-5.3',
      summary: getBuildingLifecycleSummary_(spreadsheet, buildingRecord)
    },
    null,
    null
  );
}

/**
 * 建物を非表示にする。子Visit / PhotoとDriveファイルは変更しない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleHideBuilding(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var buildingRecord = requireBuildingLifecycleRecord_(
      spreadsheet,
      buildingId
    );
    var driveFolderId = optionalSheetString_(
      buildingRecord.object.driveFolderId
    );
    if (driveFolderId === null) {
      throw createApiError_(
        'NOT_FOUND',
        'この建物は完全削除済みのため非表示操作を行えません。'
      );
    }

    var alreadyHidden = sheetBoolean_(buildingRecord.object.isDeleted);
    if (!alreadyHidden) {
      setBuildingLifecycleHidden_(spreadsheet, buildingRecord, true);
      SpreadsheetApp.flush();
    }

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.3',
        buildingId: buildingId,
        hidden: true,
        reused: alreadyHidden
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 非表示建物を復元する。
 * 建物の元画像フォルダがアプリの保存ルート直下に残っている場合のみ復元する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleRestoreBuilding(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var buildingRecord = requireBuildingLifecycleRecord_(
      spreadsheet,
      buildingId
    );
    var driveFolderId = optionalSheetString_(
      buildingRecord.object.driveFolderId
    );
    if (driveFolderId === null) {
      throw createApiError_(
        'NOT_FOUND',
        'この建物は完全削除済みのため復元できません。'
      );
    }

    requireBuildingLifecycleFolderInParent_(
      driveFolderId,
      getDriveSpikeFolder_().getId(),
      '建物の写真フォルダ'
    );

    var alreadyActive = !sheetBoolean_(buildingRecord.object.isDeleted);
    if (!alreadyActive) {
      setBuildingLifecycleHidden_(spreadsheet, buildingRecord, false);
      SpreadsheetApp.flush();
    }

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.3',
        buildingId: buildingId,
        hidden: false,
        reused: alreadyActive
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 建物を完全削除する。
 *
 * - 建物写真フォルダをDrive APIで永久削除
 * - サムネイル建物フォルダをDrive APIで永久削除
 * - Photos行はisDeleted=true、storageFileId/thumbnailFileIdを空欄化
 * - Visits行はisDeleted=true
 * - Buildings行はisDeleted=true、driveFolderId/coverPhotoIdを空欄化
 *
 * Sheets行はID履歴のため物理削除しない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleDeleteBuildingPermanently(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  requirePhotoLifecycleAdvancedDriveService_();

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var buildingRecord = requireBuildingLifecycleRecord_(
      spreadsheet,
      buildingId
    );
    var driveFolderId = optionalSheetString_(
      buildingRecord.object.driveFolderId
    );
    var alreadyPermanentlyDeleted =
      sheetBoolean_(buildingRecord.object.isDeleted) &&
      driveFolderId === null;

    if (alreadyPermanentlyDeleted) {
      return createApiResponse(
        true,
        normalizedRequestId,
        {
          stage: '5-5.3',
          buildingId: buildingId,
          permanentlyDeleted: true,
          reused: true
        },
        null,
        null
      );
    }

    // 先に一覧から外す。Drive削除で一時エラーになっても、
    // 非表示建物管理から同じbuildingIdで完全削除を再試行できる。
    if (!sheetBoolean_(buildingRecord.object.isDeleted)) {
      setBuildingLifecycleHidden_(spreadsheet, buildingRecord, true);
      SpreadsheetApp.flush();
    }

    if (driveFolderId !== null) {
      deleteBuildingLifecycleFolder_(
        driveFolderId,
        getDriveSpikeFolder_().getId(),
        '建物の写真フォルダ'
      );
    }

    var thumbnailFolderId = findPhotoLifecycleThumbnailFolderId_(buildingId);
    if (thumbnailFolderId !== null) {
      var thumbnailParentId = findBuildingLifecycleThumbnailRootId_();
      if (thumbnailParentId === null) {
        throw createApiError_(
          'VALIDATION_ERROR',
          'サムネイルフォルダの保存場所を確認できないため、安全のため削除を中止しました。'
        );
      }
      deleteBuildingLifecycleFolder_(
        thumbnailFolderId,
        thumbnailParentId,
        '建物のサムネイルフォルダ'
      );
    }

    clearBuildingLifecyclePhotoRows_(spreadsheet, buildingId);
    markBuildingLifecycleVisitRowsDeleted_(spreadsheet, buildingId);

    var refreshedBuildingRecord = requireBuildingLifecycleRecord_(
      spreadsheet,
      buildingId
    );
    finalizeBuildingLifecycleDeletion_(
      spreadsheet,
      refreshedBuildingRecord
    );
    SpreadsheetApp.flush();

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.3',
        buildingId: buildingId,
        permanentlyDeleted: true,
        reused: false
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} buildingId
 * @return {Object}
 */
function requireBuildingLifecycleRecord_(spreadsheet, buildingId) {
  var record = findSheetRecordById_(
    spreadsheet,
    'Buildings',
    'buildingId',
    buildingId
  );
  if (record === null) {
    throw createApiError_('NOT_FOUND', '建物が見つかりませんでした。');
  }
  return record;
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} buildingRecord
 * @return {Object}
 */
function getBuildingLifecycleSummary_(spreadsheet, buildingRecord) {
  var buildingObject = buildingRecord.object || buildingRecord;
  var building = normalizeBuildingRow_(buildingObject);
  var buildingId = building.buildingId;
  var visits = readSheetRecordsByField_(
    spreadsheet,
    'Visits',
    'buildingId',
    buildingId
  );
  var photos = readSheetRecordsByField_(
    spreadsheet,
    'Photos',
    'buildingId',
    buildingId
  );

  var visitCount = visits.filter(function(record) {
    return !sheetBoolean_(record.object.isDeleted);
  }).length;
  var photoCount = 0;
  var photoBytes = 0;
  photos.forEach(function(record) {
    if (optionalSheetString_(record.object.storageFileId) === null) {
      return;
    }
    photoCount += 1;
    var byteSize = Number(record.object.byteSize);
    if (isFinite(byteSize) && byteSize > 0) {
      photoBytes += Math.floor(byteSize);
    }
  });

  return {
    building: building,
    visitCount: visitCount,
    photoCount: photoCount,
    photoBytes: photoBytes
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} buildingRecord
 * @param {boolean} isDeleted
 */
function setBuildingLifecycleHidden_(spreadsheet, buildingRecord, isDeleted) {
  var definition = findSheetDefinition_('Buildings');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  var updatedAtIndex = definition.headers.indexOf('updatedAt');
  if (isDeletedIndex < 0 || updatedAtIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Buildingsシートの削除列定義が正しくありません。'
    );
  }

  var values = buildingRecord.values.slice();
  values[isDeletedIndex] = isDeleted;
  values[updatedAtIndex] = new Date();
  updateSheetRecord_(
    spreadsheet,
    'Buildings',
    buildingRecord.rowNumber,
    values
  );
  buildingRecord.values = values;
  buildingRecord.object.isDeleted = isDeleted;
  buildingRecord.object.updatedAt = values[updatedAtIndex];
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} buildingId
 */
function clearBuildingLifecyclePhotoRows_(spreadsheet, buildingId) {
  var definition = findSheetDefinition_('Photos');
  var storageFileIdIndex = definition.headers.indexOf('storageFileId');
  var thumbnailFileIdIndex = definition.headers.indexOf('thumbnailFileId');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  if (
    storageFileIdIndex < 0 ||
    thumbnailFileIdIndex < 0 ||
    isDeletedIndex < 0
  ) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Photosシートの保存先列定義が正しくありません。'
    );
  }

  readSheetRecordsByField_(
    spreadsheet,
    'Photos',
    'buildingId',
    buildingId
  ).forEach(function(record) {
    var values = record.values.slice();
    values[storageFileIdIndex] = '';
    values[thumbnailFileIdIndex] = '';
    values[isDeletedIndex] = true;
    updateSheetRecord_(spreadsheet, 'Photos', record.rowNumber, values);
  });
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} buildingId
 */
function markBuildingLifecycleVisitRowsDeleted_(spreadsheet, buildingId) {
  var definition = findSheetDefinition_('Visits');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  var updatedAtIndex = definition.headers.indexOf('updatedAt');
  if (isDeletedIndex < 0 || updatedAtIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Visitsシートの削除列定義が正しくありません。'
    );
  }

  readSheetRecordsByField_(
    spreadsheet,
    'Visits',
    'buildingId',
    buildingId
  ).forEach(function(record) {
    var values = record.values.slice();
    values[isDeletedIndex] = true;
    values[updatedAtIndex] = new Date();
    updateSheetRecord_(spreadsheet, 'Visits', record.rowNumber, values);
  });
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} buildingRecord
 */
function finalizeBuildingLifecycleDeletion_(spreadsheet, buildingRecord) {
  var definition = findSheetDefinition_('Buildings');
  var driveFolderIdIndex = definition.headers.indexOf('driveFolderId');
  var coverPhotoIdIndex = definition.headers.indexOf('coverPhotoId');
  var updatedAtIndex = definition.headers.indexOf('updatedAt');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  if (
    driveFolderIdIndex < 0 ||
    coverPhotoIdIndex < 0 ||
    updatedAtIndex < 0 ||
    isDeletedIndex < 0
  ) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Buildingsシートの保存先列定義が正しくありません。'
    );
  }

  var values = buildingRecord.values.slice();
  values[driveFolderIdIndex] = '';
  values[coverPhotoIdIndex] = '';
  values[updatedAtIndex] = new Date();
  values[isDeletedIndex] = true;
  updateSheetRecord_(
    spreadsheet,
    'Buildings',
    buildingRecord.rowNumber,
    values
  );
}

/**
 * Folderが指定親フォルダ直下にあることを確認する。
 *
 * @param {string} folderId
 * @param {string} expectedParentId
 * @param {string} label
 * @return {GoogleAppsScript.Drive.Folder}
 */
function requireBuildingLifecycleFolderInParent_(
  folderId,
  expectedParentId,
  label
) {
  var folder;
  try {
    folder = DriveApp.getFolderById(folderId);
  } catch (error) {
    throw createApiError_('NOT_FOUND', label + 'がGoogle Driveに見つかりません。');
  }

  if (folder.isTrashed()) {
    throw createApiError_('NOT_FOUND', label + 'がGoogle Driveに見つかりません。');
  }

  var parents = folder.getParents();
  while (parents.hasNext()) {
    if (parents.next().getId() === expectedParentId) {
      return folder;
    }
  }

  throw createApiError_(
    'VALIDATION_ERROR',
    label + 'の保存場所が想定と異なるため、安全のため操作を中止しました。'
  );
}

/**
 * 高度なDrive APIでフォルダを永久削除する。
 * すでに存在しない場合は再送時の冪等性のため成功扱いにする。
 *
 * @param {string} folderId
 * @param {string} expectedParentId
 * @param {string} label
 */
function deleteBuildingLifecycleFolder_(folderId, expectedParentId, label) {
  var folder;
  try {
    folder = DriveApp.getFolderById(folderId);
  } catch (missingError) {
    return;
  }

  if (!folder.isTrashed()) {
    requireBuildingLifecycleFolderInParent_(
      folderId,
      expectedParentId,
      label
    );
  }

  try {
    Drive.Files.remove(folderId);
  } catch (error) {
    throw createApiError_(
      'DRIVE_DELETE_FAILED',
      label + 'をGoogle Driveから完全削除できませんでした。もう一度お試しください。'
    );
  }
}

/**
 * 既存のサムネイルルートを探す。削除操作なので新規作成はしない。
 *
 * @return {string|null}
 */
function findBuildingLifecycleThumbnailRootId_() {
  var root = getDriveSpikeFolder_();
  var folders = root.getFoldersByName(RECORD_THUMBNAIL_ROOT_FOLDER_NAME);
  return folders.hasNext() ? folders.next().getId() : null;
}
