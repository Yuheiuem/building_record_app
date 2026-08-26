/**
 * 段階5-5.4: Visitの非表示・復元・完全削除。
 *
 * 非表示はVisits.isDeletedのみを変更し、Photo行とDriveファイルは保持する。
 * 完全削除はVisit配下の元画像・サムネイルをDriveから永久削除し、
 * Photos行は履歴のため残したまま保存先IDを空欄化する。
 */

/**
 * 指定建物の復元可能な非表示Visitを返す。
 * status=deleted の完全削除済みVisitは返さない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetHiddenBuildingVisits(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var spreadsheet = getDataSpreadsheet_();
  requireActiveSheetRecord_(
    spreadsheet,
    'Buildings',
    'buildingId',
    buildingId
  );

  var summaries = readSheetRecordsByField_(
    spreadsheet,
    'Visits',
    'buildingId',
    buildingId
  )
    .filter(function(record) {
      return sheetBoolean_(record.object.isDeleted) &&
        optionalSheetString_(record.object.status) === 'completed';
    })
    .map(function(record) {
      return getVisitLifecycleSummary_(spreadsheet, record);
    })
    .sort(function(left, right) {
      return String(right.visit.visitedAt || '').localeCompare(
        String(left.visit.visitedAt || '')
      );
    });

  return createApiResponse(
    true,
    requestId,
    {
      stage: '5-5.4',
      buildingId: buildingId,
      visits: summaries
    },
    null,
    null
  );
}

/**
 * Visitを非表示にする。Photo行・Driveファイルは変更しない。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleHideVisit(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeVisitLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requireVisitLifecycleContext_(spreadsheet, normalized);
    var status = optionalSheetString_(context.visitRecord.object.status);
    if (status === 'deleted') {
      throw createApiError_(
        'NOT_FOUND',
        'この訪問記録は完全削除済みのため非表示操作を行えません。'
      );
    }
    if (status !== 'completed') {
      throw createApiError_(
        'VALIDATION_ERROR',
        '完了済みの訪問記録だけ非表示にできます。'
      );
    }

    var alreadyHidden = sheetBoolean_(context.visitRecord.object.isDeleted);
    if (!alreadyHidden) {
      setVisitLifecycleHidden_(spreadsheet, context.visitRecord, true);
      SpreadsheetApp.flush();
    }

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.4',
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
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
 * 非表示Visitを復元する。
 * Photo個別のisDeletedは変更しないため、写真単体で非表示にした状態は保持される。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleRestoreVisit(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeVisitLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requireVisitLifecycleContext_(spreadsheet, normalized);
    var status = optionalSheetString_(context.visitRecord.object.status);
    if (status === 'deleted') {
      throw createApiError_(
        'NOT_FOUND',
        'この訪問記録は完全削除済みのため復元できません。'
      );
    }
    if (status !== 'completed') {
      throw createApiError_(
        'VALIDATION_ERROR',
        '完了済みの訪問記録だけ復元できます。'
      );
    }

    var alreadyActive = !sheetBoolean_(context.visitRecord.object.isDeleted);
    if (!alreadyActive) {
      setVisitLifecycleHidden_(spreadsheet, context.visitRecord, false);
      SpreadsheetApp.flush();
    }

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.4',
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
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
 * 非表示Visitを完全削除する。
 *
 * - 先にVisitを非表示にして通常画面から除外する
 * - 配下Photoの元画像・サムネイルをDrive APIで永久削除する
 * - Photos行はisDeleted=true、storageFileId/thumbnailFileIdを空欄化する
 * - Visits行はisDeleted=true、status=deleted として履歴を残す
 * - 代表写真が対象Visit内なら、別の有効写真へ自動切替する
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleDeleteVisitPermanently(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  requirePhotoLifecycleAdvancedDriveService_();
  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeVisitLifecycleMutationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    var context = requireVisitLifecycleContext_(spreadsheet, normalized);
    var status = optionalSheetString_(context.visitRecord.object.status);
    if (
      status === 'deleted' &&
      sheetBoolean_(context.visitRecord.object.isDeleted)
    ) {
      return createApiResponse(
        true,
        normalizedRequestId,
        {
          stage: '5-5.4',
          buildingId: normalized.buildingId,
          visitId: normalized.visitId,
          permanentlyDeleted: true,
          reused: true
        },
        null,
        null
      );
    }
    if (status !== 'completed') {
      throw createApiError_(
        'VALIDATION_ERROR',
        '完了済みの訪問記録だけ完全削除できます。'
      );
    }
    if (!sheetBoolean_(context.visitRecord.object.isDeleted)) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '安全のため、先に訪問記録を非表示にしてから完全削除してください。'
      );
    }

    var buildingFolderId = optionalSheetString_(
      context.buildingRecord.object.driveFolderId
    );
    if (buildingFolderId === null) {
      throw createApiError_(
        'NOT_FOUND',
        '建物の写真フォルダが見つからないため削除できません。'
      );
    }

    var photoRecords = readSheetRecordsByField_(
      spreadsheet,
      'Photos',
      'visitId',
      normalized.visitId
    ).filter(function(record) {
      return optionalSheetString_(record.object.buildingId) === normalized.buildingId;
    });

    var coverPhotoId = optionalSheetString_(
      context.buildingRecord.object.coverPhotoId
    );
    var coverBelongsToVisit = photoRecords.some(function(record) {
      return optionalSheetString_(record.object.photoId) === coverPhotoId;
    });
    if (coverBelongsToVisit) {
      var replacementCoverPhotoId = findPhotoLifecycleReplacementCoverPhotoId_(
        spreadsheet,
        normalized.buildingId,
        coverPhotoId
      );
      setPhotoLifecycleCoverPhotoId_(
        spreadsheet,
        context.buildingRecord,
        replacementCoverPhotoId
      );
      SpreadsheetApp.flush();
    }

    var thumbnailFolderId = findPhotoLifecycleThumbnailFolderId_(
      normalized.buildingId
    );

    photoRecords.forEach(function(photoRecord) {
      var storageFileId = optionalSheetString_(photoRecord.object.storageFileId);
      var thumbnailFileId = optionalSheetString_(
        photoRecord.object.thumbnailFileId
      );

      if (storageFileId !== null) {
        deletePhotoLifecycleDriveFile_(
          storageFileId,
          buildingFolderId,
          '訪問写真'
        );
      }
      if (thumbnailFileId !== null) {
        if (thumbnailFolderId === null) {
          throw createApiError_(
            'VALIDATION_ERROR',
            'サムネイルフォルダの保存場所を確認できないため、安全のため削除を中止しました。'
          );
        }
        deletePhotoLifecycleDriveFile_(
          thumbnailFileId,
          thumbnailFolderId,
          '訪問写真のサムネイル'
        );
      }

      clearPhotoLifecycleStorageIds_(spreadsheet, photoRecord);
    });

    markVisitLifecyclePermanentlyDeleted_(
      spreadsheet,
      context.visitRecord
    );
    SpreadsheetApp.flush();

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-5.4',
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
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
 * @param {Object} payload
 * @return {{buildingId: string, visitId: string}}
 */
function normalizeVisitLifecycleMutationPayload_(payload) {
  return {
    buildingId: getBuildingDetailRequiredId_(payload, 'buildingId'),
    visitId: getBuildingDetailRequiredId_(payload, 'visitId')
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {{buildingId: string, visitId: string}} normalized
 * @return {{buildingRecord: Object, visitRecord: Object}}
 */
function requireVisitLifecycleContext_(spreadsheet, normalized) {
  var buildingRecord = requireActiveSheetRecord_(
    spreadsheet,
    'Buildings',
    'buildingId',
    normalized.buildingId
  );
  var visitRecord = findSheetRecordById_(
    spreadsheet,
    'Visits',
    'visitId',
    normalized.visitId
  );
  if (visitRecord === null) {
    throw createApiError_('NOT_FOUND', '訪問記録が見つかりませんでした。');
  }
  if (
    optionalSheetString_(visitRecord.object.buildingId) !== normalized.buildingId
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '選択した訪問記録はこの建物の記録ではありません。'
    );
  }
  return {
    buildingRecord: buildingRecord,
    visitRecord: visitRecord
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} visitRecord
 * @return {{visit: Object, photoCount: number, photoBytes: number}}
 */
function getVisitLifecycleSummary_(spreadsheet, visitRecord) {
  var visit = normalizeBuildingDetailVisitRow_(visitRecord.object || visitRecord);
  var photoCount = 0;
  var photoBytes = 0;
  readSheetRecordsByField_(
    spreadsheet,
    'Photos',
    'visitId',
    visit.visitId
  ).forEach(function(record) {
    if (optionalSheetString_(record.object.storageFileId) === null) {
      return;
    }
    photoCount += 1;
    var byteSize = Number(record.object.byteSize);
    if (isFinite(byteSize) && byteSize > 0) {
      photoBytes += Math.floor(byteSize);
    }
  });
  delete visit.isDeleted;
  return {
    visit: visit,
    photoCount: photoCount,
    photoBytes: photoBytes
  };
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} visitRecord
 * @param {boolean} isDeleted
 */
function setVisitLifecycleHidden_(spreadsheet, visitRecord, isDeleted) {
  var definition = findSheetDefinition_('Visits');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  var updatedAtIndex = definition.headers.indexOf('updatedAt');
  if (isDeletedIndex < 0 || updatedAtIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Visitsシートの削除列定義が正しくありません。'
    );
  }
  var values = visitRecord.values.slice();
  values[isDeletedIndex] = isDeleted;
  values[updatedAtIndex] = new Date();
  updateSheetRecord_(
    spreadsheet,
    'Visits',
    visitRecord.rowNumber,
    values
  );
  visitRecord.values = values;
  visitRecord.object.isDeleted = isDeleted;
  visitRecord.object.updatedAt = values[updatedAtIndex];
}

/**
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} visitRecord
 */
function markVisitLifecyclePermanentlyDeleted_(spreadsheet, visitRecord) {
  var definition = findSheetDefinition_('Visits');
  var statusIndex = definition.headers.indexOf('status');
  var isDeletedIndex = definition.headers.indexOf('isDeleted');
  var updatedAtIndex = definition.headers.indexOf('updatedAt');
  if (statusIndex < 0 || isDeletedIndex < 0 || updatedAtIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Visitsシートの削除状態列定義が正しくありません。'
    );
  }
  var values = visitRecord.values.slice();
  values[statusIndex] = 'deleted';
  values[isDeletedIndex] = true;
  values[updatedAtIndex] = new Date();
  updateSheetRecord_(
    spreadsheet,
    'Visits',
    visitRecord.rowNumber,
    values
  );
}
