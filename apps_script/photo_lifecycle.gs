/**
 * 段階5-5.2: 写真の非表示・復元・完全削除。
 *
 * 非表示はPhotos.isDeletedのみを変更し、Driveファイルは保持する。
 * 完全削除は行を残したまま元画像・サムネイルをDriveから永久削除し、
 * storageFileId / thumbnailFileIdを空にする。
 */

/**
 * 指定建物の「非表示だが復元可能」な写真メタデータを返す。
 * 完全削除済み（storageFileIdが空）の行は返さない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetHiddenBuildingPhotos(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var spreadsheet = getDataSpreadsheet_();
  findBuildingDetailBuilding_(spreadsheet, buildingId);

  var photos = readSheetObjects_(spreadsheet, 'Photos')
    .filter(function(row) {
      return optionalSheetString_(row.buildingId) === buildingId &&
        sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.storageFileId) !== null;
    })
    .map(normalizeBuildingDetailPhotoRow_)
    .sort(photoLifecyclePhotoSort_);

  photos.forEach(function(photo) {
    delete photo.isDeleted;
  });

  return createApiResponse(
    true,
    requestId,
    {
      stage: '5-5.2',
      buildingId: buildingId,
      photos: photos
    },
    null,
    null
  );
}

/**
 * 非表示写真の確認用サムネイルを返す。
 * 通常のサムネイルAPIは削除フラグ付き写真を拒否するため、
 * このactionだけallowDeleted=trueで同じDrive検証を再利用する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetHiddenPhotoThumbnailData(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var photoId = getBuildingDetailRequiredId_(payload, 'photoId');
  var spreadsheet = getDataSpreadsheet_();
  var photoRecord = findSheetRecordById_(
    spreadsheet,
    'Photos',
    'photoId',
    photoId
  );

  if (
    photoRecord === null ||
    !sheetBoolean_(photoRecord.object.isDeleted) ||
    optionalSheetString_(photoRecord.object.storageFileId) === null
  ) {
    throw createApiError_('NOT_FOUND', '非表示写真が見つかりませんでした。');
  }

  var buildingId = optionalSheetString_(photoRecord.object.buildingId);
  if (buildingId === null) {
    throw createApiError_('INTERNAL_ERROR', '写真にbuildingIdがありません。');
  }
  findBuildingDetailBuilding_(spreadsheet, buildingId);

  return createApiResponse(
    true,
    requestId,
    getPhotoThumbnailResponseData_(
      photoId,
      spreadsheet,
      photoRecord.object,
      true
    ),
    null,
    null
  );
}

/**
 * 写真を非表示にする。Driveファイルは残すため復元可能。
 * 代表写真なら別の有効写真へ自動で切り替える。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleHidePhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizePhotoLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requirePhotoLifecycleContext_(spreadsheet, normalized);
    var storageFileId = optionalSheetString_(
      context.photoRecord.object.storageFileId
    );
    if (storageFileId === null) {
      throw createApiError_(
        'NOT_FOUND',
        'この写真は完全削除済みのため非表示操作を行えません。'
      );
    }

    var alreadyHidden = sheetBoolean_(context.photoRecord.object.isDeleted);
    var coverPhotoId = optionalSheetString_(
      context.buildingRecord.object.coverPhotoId
    );

    if (!alreadyHidden) {
      setPhotoLifecycleDeletedFlag_(
        spreadsheet,
        context.photoRecord,
        true
      );
    }

    if (coverPhotoId === normalized.photoId) {
      coverPhotoId = findPhotoLifecycleReplacementCoverPhotoId_(
        spreadsheet,
        normalized.buildingId,
        normalized.photoId
      );
      setPhotoLifecycleCoverPhotoId_(
        spreadsheet,
        context.buildingRecord,
        coverPhotoId
      );
    }

    SpreadsheetApp.flush();
    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.2',
        buildingId: normalized.buildingId,
        photoId: normalized.photoId,
        hidden: true,
        coverPhotoId: coverPhotoId,
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
 * 非表示写真を復元する。
 * 元画像がDriveに存在し、対象建物フォルダ内にある場合のみ復元する。
 * 建物に代表写真がない場合は復元写真を代表写真にする。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleRestorePhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizePhotoLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requirePhotoLifecycleContext_(spreadsheet, normalized);
    var storageFileId = optionalSheetString_(
      context.photoRecord.object.storageFileId
    );
    if (storageFileId === null) {
      throw createApiError_(
        'NOT_FOUND',
        'この写真は完全削除済みのため復元できません。'
      );
    }

    var visitId = optionalSheetString_(context.photoRecord.object.visitId);
    if (visitId === null) {
      throw createApiError_('INTERNAL_ERROR', '写真にvisitIdがありません。');
    }
    var visitRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Visits',
      'visitId',
      visitId
    );
    if (
      optionalSheetString_(visitRecord.object.buildingId) !== normalized.buildingId ||
      optionalSheetString_(visitRecord.object.status) !== 'completed'
    ) {
      throw createApiError_(
        'VALIDATION_ERROR',
        'この写真の訪問記録が有効ではないため復元できません。'
      );
    }

    var expectedFolderId = optionalSheetString_(
      context.buildingRecord.object.driveFolderId
    );
    if (expectedFolderId === null) {
      throw createApiError_('INTERNAL_ERROR', '建物のDriveフォルダが未設定です。');
    }
    requirePhotoLifecycleDriveFileInFolder_(
      storageFileId,
      expectedFolderId,
      '元画像'
    );

    var alreadyActive = !sheetBoolean_(context.photoRecord.object.isDeleted);
    if (!alreadyActive) {
      setPhotoLifecycleDeletedFlag_(
        spreadsheet,
        context.photoRecord,
        false
      );
    }

    var coverPhotoId = optionalSheetString_(
      context.buildingRecord.object.coverPhotoId
    );
    if (coverPhotoId === null) {
      coverPhotoId = normalized.photoId;
      setPhotoLifecycleCoverPhotoId_(
        spreadsheet,
        context.buildingRecord,
        coverPhotoId
      );
    }

    SpreadsheetApp.flush();
    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.2',
        buildingId: normalized.buildingId,
        photoId: normalized.photoId,
        hidden: false,
        coverPhotoId: coverPhotoId,
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
 * 写真の元画像とサムネイルをDriveから永久削除する。
 * Photos行は監査・ID履歴のため残し、isDeleted=trueかつ
 * storageFileId / thumbnailFileIdを空にして「復元不可」を表す。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleDeletePhotoPermanently(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  requirePhotoLifecycleAdvancedDriveService_();

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizePhotoLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requirePhotoLifecycleContext_(spreadsheet, normalized);
    var storageFileId = optionalSheetString_(
      context.photoRecord.object.storageFileId
    );
    var thumbnailFileId = optionalSheetString_(
      context.photoRecord.object.thumbnailFileId
    );
    var alreadyPermanentlyDeleted =
      sheetBoolean_(context.photoRecord.object.isDeleted) &&
      storageFileId === null &&
      thumbnailFileId === null;

    var coverPhotoId = optionalSheetString_(
      context.buildingRecord.object.coverPhotoId
    );
    if (coverPhotoId === normalized.photoId) {
      coverPhotoId = findPhotoLifecycleReplacementCoverPhotoId_(
        spreadsheet,
        normalized.buildingId,
        normalized.photoId
      );
      setPhotoLifecycleCoverPhotoId_(
        spreadsheet,
        context.buildingRecord,
        coverPhotoId
      );
    }

    if (alreadyPermanentlyDeleted) {
      SpreadsheetApp.flush();
      return createApiResponse(
        true,
        normalizedRequestId,
        {
          stage: '5-5.2',
          buildingId: normalized.buildingId,
          photoId: normalized.photoId,
          permanentlyDeleted: true,
          coverPhotoId: coverPhotoId,
          reused: true
        },
        null,
        null
      );
    }

    // 外部Drive削除が途中で失敗しても通常ギャラリーに壊れた画像を残さないよう、
    // 先に論理削除して代表写真を切り替える。再送時は残ったファイルだけ削除する。
    if (!sheetBoolean_(context.photoRecord.object.isDeleted)) {
      setPhotoLifecycleDeletedFlag_(
        spreadsheet,
        context.photoRecord,
        true
      );
    }
    SpreadsheetApp.flush();

    if (storageFileId !== null) {
      var buildingFolderId = optionalSheetString_(
        context.buildingRecord.object.driveFolderId
      );
      if (buildingFolderId === null) {
        throw createApiError_('INTERNAL_ERROR', '建物のDriveフォルダが未設定です。');
      }
      deletePhotoLifecycleDriveFile_(
        storageFileId,
        buildingFolderId,
        '元画像'
      );
    }

    if (thumbnailFileId !== null) {
      var thumbnailFolderId = findPhotoLifecycleThumbnailFolderId_(
        normalized.buildingId
      );
      deletePhotoLifecycleDriveFile_(
        thumbnailFileId,
        thumbnailFolderId,
        'サムネイル'
      );
    }

    // 物理削除完了後に保存先IDを空にし、復元対象一覧から除外する。
    var refreshedPhotoRecord = findSheetRecordById_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    if (refreshedPhotoRecord === null) {
      throw createApiError_('INTERNAL_ERROR', '写真行を再取得できませんでした。');
    }
    clearPhotoLifecycleStorageIds_(spreadsheet, refreshedPhotoRecord);
    SpreadsheetApp.flush();

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.2',
        buildingId: normalized.buildingId,
        photoId: normalized.photoId,
        permanentlyDeleted: true,
        coverPhotoId: coverPhotoId,
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
 * @param {Object} payload
 * @return {{buildingId: string, photoId: string}}
 */
function normalizePhotoLifecycleMutationPayload_(payload) {
  return {
    buildingId: getBuildingDetailRequiredId_(payload, 'buildingId'),
    photoId: getBuildingDetailRequiredId_(payload, 'photoId')
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {{buildingId: string, photoId: string}} normalized
 * @return {{buildingRecord: Object, photoRecord: Object}}
 */
function requirePhotoLifecycleContext_(spreadsheet, normalized) {
  var buildingRecord = requireActiveSheetRecord_(
    spreadsheet,
    'Buildings',
    'buildingId',
    normalized.buildingId
  );
  var photoRecord = findSheetRecordById_(
    spreadsheet,
    'Photos',
    'photoId',
    normalized.photoId
  );
  if (photoRecord === null) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }
  if (
    optionalSheetString_(photoRecord.object.buildingId) !== normalized.buildingId
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '選択した写真はこの建物の写真ではありません。'
    );
  }
  return {
    buildingRecord: buildingRecord,
    photoRecord: photoRecord
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} photoRecord findSheetRecordById_の戻り値
 * @param {boolean} isDeleted
 */
function setPhotoLifecycleDeletedFlag_(spreadsheet, photoRecord, isDeleted) {
  var definition = findSheetDefinition_('Photos');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  if (isDeletedIndex < 0) {
    throw createApiError_('INTERNAL_ERROR', 'Photosシートの削除列定義が正しくありません。');
  }
  var values = photoRecord.values.slice();
  values[isDeletedIndex] = isDeleted;
  updateSheetRecord_(
    spreadsheet,
    'Photos',
    photoRecord.rowNumber,
    values
  );
  photoRecord.values = values;
  photoRecord.object.isDeleted = isDeleted;
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} photoRecord findSheetRecordById_の戻り値
 */
function clearPhotoLifecycleStorageIds_(spreadsheet, photoRecord) {
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

  var values = photoRecord.values.slice();
  values[storageFileIdIndex] = '';
  values[thumbnailFileIdIndex] = '';
  values[isDeletedIndex] = true;
  updateSheetRecord_(
    spreadsheet,
    'Photos',
    photoRecord.rowNumber,
    values
  );
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} buildingRecord findSheetRecordById_の戻り値
 * @param {string|null} photoId
 */
function setPhotoLifecycleCoverPhotoId_(spreadsheet, buildingRecord, photoId) {
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
  values[coverPhotoIdIndex] = photoId || '';
  values[updatedAtIndex] = new Date();
  updateSheetRecord_(
    spreadsheet,
    'Buildings',
    buildingRecord.rowNumber,
    values
  );
  buildingRecord.values = values;
  buildingRecord.object.coverPhotoId = photoId || '';
  buildingRecord.object.updatedAt = values[updatedAtIndex];
}

/**
 * 対象以外の有効写真から、建物詳細と同じ優先順で新しい代表写真を選ぶ。
 * 完了済みかつ非削除のVisitに紐づく写真だけを候補にする。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} buildingId
 * @param {string} excludedPhotoId
 * @return {string|null}
 */
function findPhotoLifecycleReplacementCoverPhotoId_(
  spreadsheet,
  buildingId,
  excludedPhotoId
) {
  var activeVisitIds = {};
  readSheetObjects_(spreadsheet, 'Visits').forEach(function(row) {
    var visitId = optionalSheetString_(row.visitId);
    if (
      optionalSheetString_(row.buildingId) === buildingId &&
      !sheetBoolean_(row.isDeleted) &&
      optionalSheetString_(row.status) === 'completed' &&
      visitId !== null
    ) {
      activeVisitIds[visitId] = true;
    }
  });

  var photos = readSheetObjects_(spreadsheet, 'Photos')
    .filter(function(row) {
      var photoId = optionalSheetString_(row.photoId);
      var visitId = optionalSheetString_(row.visitId);
      return optionalSheetString_(row.buildingId) === buildingId &&
        photoId !== null &&
        photoId !== excludedPhotoId &&
        !sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.storageFileId) !== null &&
        visitId !== null &&
        activeVisitIds[visitId] === true;
    })
    .map(normalizeBuildingDetailPhotoRow_)
    .sort(photoLifecyclePhotoSort_);

  return photos.length === 0 ? null : photos[0].photoId;
}

/**
 * @param {Object} left
 * @param {Object} right
 * @return {number}
 */
function photoLifecyclePhotoSort_(left, right) {
  var timeDifference = String(right.takenAt || right.createdAt || '')
    .localeCompare(String(left.takenAt || left.createdAt || ''));
  if (timeDifference !== 0) {
    return timeDifference;
  }
  return left.displayOrder - right.displayOrder;
}

/**
 * 復元前に元画像が正しい建物フォルダに残っていることを確認する。
 *
 * @param {string} fileId
 * @param {string} expectedFolderId
 * @param {string} label
 * @return {GoogleAppsScript.Drive.File}
 */
function requirePhotoLifecycleDriveFileInFolder_(
  fileId,
  expectedFolderId,
  label
) {
  var file;
  try {
    file = DriveApp.getFileById(fileId);
  } catch (error) {
    throw createApiError_('NOT_FOUND', label + 'がGoogle Driveに見つかりません。');
  }
  if (
    file.isTrashed() ||
    !isBuildingDetailFileInFolder_(file, expectedFolderId)
  ) {
    throw createApiError_('NOT_FOUND', label + 'がGoogle Driveに見つかりません。');
  }
  return file;
}

/**
 * 高度なDrive APIでファイルを永久削除する。
 * すでに存在しないファイルは再送時の冪等性のため成功扱いにする。
 *
 * @param {string} fileId
 * @param {string|null} expectedFolderId
 * @param {string} label
 */
function deletePhotoLifecycleDriveFile_(fileId, expectedFolderId, label) {
  var file;
  try {
    file = DriveApp.getFileById(fileId);
  } catch (missingError) {
    return;
  }

  if (
    expectedFolderId === null ||
    !isBuildingDetailFileInFolder_(file, expectedFolderId)
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      label + 'の保存場所が想定と異なるため、安全のため削除を中止しました。'
    );
  }

  try {
    Drive.Files.remove(fileId);
  } catch (error) {
    throw createApiError_(
      'DRIVE_DELETE_FAILED',
      label + 'をGoogle Driveから完全削除できませんでした。もう一度お試しください。'
    );
  }
}

/**
 * 既存のサムネイルフォルダを探す。削除処理なので新規作成はしない。
 *
 * @param {string} buildingId
 * @return {string|null}
 */
function findPhotoLifecycleThumbnailFolderId_(buildingId) {
  var root = getDriveSpikeFolder_();
  var thumbnailRoots = root.getFoldersByName(RECORD_THUMBNAIL_ROOT_FOLDER_NAME);
  if (!thumbnailRoots.hasNext()) {
    return null;
  }
  var thumbnailRoot = thumbnailRoots.next();
  var buildingFolders = thumbnailRoot.getFoldersByName(buildingId);
  if (!buildingFolders.hasNext()) {
    return null;
  }
  return buildingFolders.next().getId();
}

/**
 * 完全削除には高度なDriveサービスが必要。
 * 未有効時にReferenceErrorへ落ちず、UIへ設定不足を返す。
 */
function requirePhotoLifecycleAdvancedDriveService_() {
  if (
    typeof Drive === 'undefined' ||
    !Drive.Files ||
    typeof Drive.Files.remove !== 'function'
  ) {
    throw createApiError_(
      'CONFIGURATION_ERROR',
      '完全削除にはApps Scriptの「Drive API」サービスを有効化してください。'
    );
  }
}
