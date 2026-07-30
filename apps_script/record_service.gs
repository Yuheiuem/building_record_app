var RECORD_MAX_PHOTO_BYTES = 5 * 1024 * 1024;
var RECORD_ALLOWED_MIME_TYPES = {
  'image/jpeg': '.jpg',
  'image/png': '.png'
};
var RECORD_LOCATION_SOURCES = [
  'gps',
  'building_fallback',
  'manual'
];

/**
 * 建物・訪問のdraftを作成する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleBeginRecord(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalized = normalizeBeginRecordPayload_(requestId, payload);
  var spreadsheet = getDataSpreadsheet_();
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);

  try {
    var cached = getRequestResult_(
      spreadsheet,
      normalized.requestId,
      'beginRecord'
    );
    if (cached !== null) {
      cached.reused = true;
      return createApiResponse(true, requestId, cached, null, null);
    }

    validateRecordTagIds_(spreadsheet, normalized);

    var buildingResult = ensureRecordBuilding_(spreadsheet, normalized);
    var visitResult = ensureRecordVisit_(spreadsheet, normalized);
    var result = {
      buildingId: normalized.buildingId,
      visitId: normalized.visitId,
      expectedPhotoCount: normalized.expectedPhotoCount,
      buildingCreated: buildingResult.created,
      visitCreated: visitResult.created,
      reused: false,
      stage: '3-4B'
    };

    appendRequestResult_(
      spreadsheet,
      normalized.requestId,
      'beginRecord',
      result,
      {
        buildingId: normalized.buildingId,
        visitId: normalized.visitId
      },
      true
    );

    return createApiResponse(true, requestId, result, null, null);
  } finally {
    lock.releaseLock();
  }
}

/**
 * 写真を1枚ずつ非公開Driveへ保存し、Photosシートへ登録する。
 * recordDraftを同梱した場合は建物・訪問の準備も同じ通信内で行い、
 * finalizeAfterUploadがtrueなら写真保存後に記録を確定する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUploadPhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var handlerStartedAt = Date.now();
  var timings = {
    authenticationMs: Number(authContext.verificationMs) || 0,
    lockWaitMs: 0,
    draftPreparationMs: 0,
    lookupMs: 0,
    base64DecodeMs: 0,
    driveSaveMs: 0,
    sheetWriteMs: 0,
    finalizeMs: 0
  };
  var normalized = normalizeUploadPhotoPayload_(requestId, payload);

  var decodeStartedAt = Date.now();
  var bytes;
  try {
    bytes = Utilities.base64Decode(normalized.base64Data);
  } catch (error) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像データが正しいBase64ではありません。'
    );
  }
  timings.base64DecodeMs = Date.now() - decodeStartedAt;

  if (bytes.length !== normalized.byteSize) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像データのサイズが申告値と一致しません。'
    );
  }
  if (bytes.length > RECORD_MAX_PHOTO_BYTES) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像サイズが5MBを超えています。'
    );
  }

  var spreadsheet = getDataSpreadsheet_();
  var lock = LockService.getScriptLock();
  var lockStartedAt = Date.now();
  lock.waitLock(30000);
  timings.lockWaitMs = Date.now() - lockStartedAt;

  try {
    var lookupStartedAt = Date.now();
    var cached = getRequestResult_(
      spreadsheet,
      normalized.requestId,
      'uploadPhoto'
    );
    if (cached !== null) {
      timings.lookupMs = Date.now() - lookupStartedAt;
      cached.reused = true;
      attachUploadPerformance_(
        cached,
        authContext,
        timings,
        handlerStartedAt
      );
      return createApiResponse(true, requestId, cached, null, null);
    }

    var preparation = {
      prepared: false,
      buildingCreated: false,
      visitCreated: false
    };
    if (normalized.recordDraft !== null) {
      var preparationStartedAt = Date.now();
      preparation = prepareRecordDraftForUpload_(
        spreadsheet,
        normalized.recordDraft
      );
      timings.draftPreparationMs = Date.now() - preparationStartedAt;
    }

    var buildingRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Buildings',
      'buildingId',
      normalized.buildingId
    );
    var visitRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Visits',
      'visitId',
      normalized.visitId
    );

    if (String(visitRecord.object.buildingId) !== normalized.buildingId) {
      throw createApiError_(
        'CONFLICT',
        '訪問記録と建物が一致しません。'
      );
    }

    var existingPhoto = findSheetRecordById_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    timings.lookupMs = Date.now() - lookupStartedAt;

    var result;
    if (existingPhoto !== null) {
      validateExistingPhotoRecord_(existingPhoto, normalized);
      result = photoResultFromSheetRecord_(existingPhoto, true);
    } else {
      var driveStartedAt = Date.now();
      var buildingFolder = getRecordBuildingFolder_(
        buildingRecord,
        normalized.buildingId
      );
      var internalFileName = normalized.photoId
        + RECORD_ALLOWED_MIME_TYPES[normalized.mimeType];
      var files = buildingFolder.getFilesByName(internalFileName);
      var file;
      var reusedFile = false;

      if (files.hasNext()) {
        file = files.next();
        reusedFile = true;
      } else {
        file = buildingFolder.createFile(
          Utilities.newBlob(
            bytes,
            normalized.mimeType,
            internalFileName
          )
        );
        file.setDescription(
          'Building record photo. photoId=' + normalized.photoId
        );
      }
      timings.driveSaveMs = Date.now() - driveStartedAt;

      var photoRow = [
        normalized.photoId,
        normalized.buildingId,
        normalized.visitId,
        'google_drive',
        file.getId(),
        '',
        internalFileName,
        normalized.mimeType,
        bytes.length,
        '',
        '',
        normalized.takenAt,
        normalized.latitude,
        normalized.longitude,
        normalized.accuracyM === null ? '' : normalized.accuracyM,
        normalized.locationSource,
        normalized.displayOrder,
        new Date(),
        false
      ];

      var photoWriteStartedAt = Date.now();
      appendSheetRow_(spreadsheet, 'Photos', photoRow);
      timings.sheetWriteMs += Date.now() - photoWriteStartedAt;

      result = {
        photoId: normalized.photoId,
        storageFileId: file.getId(),
        byteSize: bytes.length,
        displayOrder: normalized.displayOrder,
        reused: reusedFile,
        stage: '3-4B'
      };
    }

    result.buildingId = normalized.buildingId;
    result.visitId = normalized.visitId;
    result.recordPrepared = preparation.prepared;
    result.buildingCreated = preparation.buildingCreated;
    result.visitCreated = preparation.visitCreated;
    result.recordCompleted = false;
    result.photoCount = null;
    result.saveMode = 'combined_photo_step';

    if (normalized.finalizeAfterUpload) {
      var finalizeStartedAt = Date.now();
      var finalizeResult = finalizeRecordInsideUpload_(
        spreadsheet,
        normalized,
        buildingRecord,
        visitRecord
      );
      timings.finalizeMs = Date.now() - finalizeStartedAt;
      result.recordCompleted = true;
      result.photoCount = finalizeResult.photoCount;
      result.recordFinalizeReused = finalizeResult.reused;
    }

    attachUploadPerformance_(
      result,
      authContext,
      timings,
      handlerStartedAt
    );

    var requestWriteStartedAt = Date.now();
    appendRequestResult_(
      spreadsheet,
      normalized.requestId,
      'uploadPhoto',
      result,
      {
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
        photoId: normalized.photoId
      },
      true
    );
    timings.sheetWriteMs += Date.now() - requestWriteStartedAt;
    attachUploadPerformance_(
      result,
      authContext,
      timings,
      handlerStartedAt
    );

    return createApiResponse(true, requestId, result, null, null);
  } finally {
    lock.releaseLock();
  }
}

function prepareRecordDraftForUpload_(spreadsheet, recordDraft) {
  validateRecordTagIds_(spreadsheet, recordDraft);
  var buildingResult = ensureRecordBuilding_(spreadsheet, recordDraft);
  var visitResult = ensureRecordVisit_(spreadsheet, recordDraft);
  return {
    prepared: true,
    buildingCreated: buildingResult.created,
    visitCreated: visitResult.created
  };
}

function finalizeRecordInsideUpload_(
  spreadsheet,
  normalized,
  buildingRecord,
  visitRecord
) {
  if (String(visitRecord.object.buildingId) !== normalized.buildingId) {
    throw createApiError_(
      'CONFLICT',
      '訪問記録と建物が一致しません。'
    );
  }

  var expectedPhotoCount = Number(visitRecord.object.expectedPhotoCount);
  var photos;
  if (expectedPhotoCount === 1) {
    var currentPhoto = requireActiveSheetRecord_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    photos = [currentPhoto];
  } else {
    photos = readSheetRecordsByField_(
      spreadsheet,
      'Photos',
      'visitId',
      normalized.visitId
    ).filter(function(record) {
      return !sheetBoolean_(record.object.isDeleted);
    });
  }

  if (photos.length !== expectedPhotoCount) {
    throw createApiError_(
      'CONFLICT',
      '写真の保存枚数が予定枚数と一致しません。'
    );
  }

  var alreadyCompleted = String(visitRecord.object.status) === 'completed';
  if (!alreadyCompleted) {
    var visitValues = visitRecord.values.slice();
    visitValues[9] = 'completed';
    visitValues[12] = new Date();
    updateSheetRecord_(
      spreadsheet,
      'Visits',
      visitRecord.rowNumber,
      visitValues
    );
  }

  var buildingValues = buildingRecord.values.slice();
  var buildingChanged = false;
  if (isBlankSheetCell_(buildingValues[10]) && photos.length > 0) {
    photos.sort(function(left, right) {
      return Number(left.object.displayOrder)
        - Number(right.object.displayOrder);
    });
    buildingValues[10] = String(photos[0].object.photoId);
    buildingChanged = true;
  }
  if (buildingChanged) {
    buildingValues[12] = new Date();
    updateSheetRecord_(
      spreadsheet,
      'Buildings',
      buildingRecord.rowNumber,
      buildingValues
    );
  }

  return {
    buildingId: normalized.buildingId,
    visitId: normalized.visitId,
    photoCount: photos.length,
    status: 'completed',
    reused: alreadyCompleted
  };
}

function attachUploadPerformance_(
  result,
  authContext,
  timings,
  handlerStartedAt
) {
  result.performance = {
    authenticationMode: getOptionalString(
      authContext.verificationMode
    ) || 'tokeninfo',
    authenticationMs: Number(timings.authenticationMs) || 0,
    lockWaitMs: Number(timings.lockWaitMs) || 0,
    draftPreparationMs: Number(timings.draftPreparationMs) || 0,
    lookupMs: Number(timings.lookupMs) || 0,
    base64DecodeMs: Number(timings.base64DecodeMs) || 0,
    driveSaveMs: Number(timings.driveSaveMs) || 0,
    sheetWriteMs: Number(timings.sheetWriteMs) || 0,
    finalizeMs: Number(timings.finalizeMs) || 0,
    handlerTotalMs: Date.now() - handlerStartedAt
  };
}

/**
 * 写真枚数を確認し、訪問をcompletedへ更新する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleFinalizeRecord(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalized = normalizeFinalizeRecordPayload_(requestId, payload);
  var spreadsheet = getDataSpreadsheet_();
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);

  try {
    var cached = getRequestResult_(
      spreadsheet,
      normalized.requestId,
      'finalizeRecord'
    );
    if (cached !== null) {
      cached.reused = true;
      return createApiResponse(true, requestId, cached, null, null);
    }

    var buildingRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Buildings',
      'buildingId',
      normalized.buildingId
    );
    var visitRecord = requireActiveSheetRecord_(
      spreadsheet,
      'Visits',
      'visitId',
      normalized.visitId
    );

    if (String(visitRecord.object.buildingId) !== normalized.buildingId) {
      throw createApiError_(
        'CONFLICT',
        '訪問記録と建物が一致しません。'
      );
    }

    var photos = readSheetRecordsByField_(
      spreadsheet,
      'Photos',
      'visitId',
      normalized.visitId
    ).filter(function(record) {
      return !sheetBoolean_(record.object.isDeleted);
    });
    var expectedPhotoCount = Number(visitRecord.object.expectedPhotoCount);

    if (photos.length !== expectedPhotoCount) {
      throw createApiError_(
        'CONFLICT',
        '写真の保存枚数が予定枚数と一致しません。'
      );
    }

    var visitValues = visitRecord.values.slice();
    visitValues[9] = 'completed';
    visitValues[12] = new Date();
    updateSheetRecord_(
      spreadsheet,
      'Visits',
      visitRecord.rowNumber,
      visitValues
    );

    var buildingValues = buildingRecord.values.slice();
    if (isBlankSheetCell_(buildingValues[10]) && photos.length > 0) {
      photos.sort(function(left, right) {
        return Number(left.object.displayOrder)
          - Number(right.object.displayOrder);
      });
      buildingValues[10] = String(photos[0].object.photoId);
    }
    buildingValues[12] = new Date();
    updateSheetRecord_(
      spreadsheet,
      'Buildings',
      buildingRecord.rowNumber,
      buildingValues
    );

    var result = {
      buildingId: normalized.buildingId,
      visitId: normalized.visitId,
      photoCount: photos.length,
      status: 'completed',
      reused: false,
      stage: '3-4B'
    };

    appendRequestResult_(
      spreadsheet,
      normalized.requestId,
      'finalizeRecord',
      result,
      {
        buildingId: normalized.buildingId,
        visitId: normalized.visitId
      },
      true
    );

    return createApiResponse(true, requestId, result, null, null);
  } finally {
    lock.releaseLock();
  }
}

function normalizeBeginRecordPayload_(requestId, payload) {
  var safe = requireRecordPayloadObject_(payload);
  var buildingMode = requireRecordString_(safe, 'buildingMode');
  if (buildingMode !== 'new' && buildingMode !== 'existing') {
    throw createApiError_(
      'VALIDATION_ERROR',
      'buildingModeが正しくありません。'
    );
  }

  var buildingName = getOptionalString(safe.buildingName);
  if (buildingMode === 'new') {
    if (buildingName === null) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '建物名を入力してください。'
      );
    }
    if (Array.from(buildingName).length > 100) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '建物名は100文字以内で入力してください。'
      );
    }
  }

  var expectedPhotoCount = requirePositiveInteger_(
    safe.expectedPhotoCount,
    'expectedPhotoCount'
  );

  return {
    requestId: requireRecordRequestId_(requestId),
    buildingMode: buildingMode,
    buildingId: buildingId,
    visitId: visitId,
    buildingName: buildingName,
    designTagIds: requireStringArray_(safe.designTagIds, 'designTagIds'),
    salesTagIds: requireStringArray_(safe.salesTagIds, 'salesTagIds'),
    constructionTagIds: requireStringArray_(
      safe.constructionTagIds,
      'constructionTagIds'
    ),
    visitedAt: requireIsoDate_(safe.visitedAt, 'visitedAt'),
    triggerTagIds: requireStringArray_(
      safe.triggerTagIds,
      'triggerTagIds'
    ),
    impression: optionalLimitedString_(safe.impression, 2000) || '',
    latitude: requireLatitude_(safe.latitude),
    longitude: requireLongitude_(safe.longitude),
    accuracyM: optionalNonNegativeNumber_(safe.accuracyM, 'accuracyM'),
    locationSource: requireLocationSource_(safe.locationSource),
    expectedPhotoCount: expectedPhotoCount
  };
}

function normalizeUploadPhotoPayload_(requestId, payload) {
  var safe = requireRecordPayloadObject_(payload);
  var mimeType = requireRecordString_(safe, 'mimeType');
  if (!RECORD_ALLOWED_MIME_TYPES[mimeType]) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'JPEGまたはPNGのみ保存できます。'
    );
  }

  var byteSize = requirePositiveInteger_(safe.byteSize, 'byteSize');
  if (byteSize > RECORD_MAX_PHOTO_BYTES) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像サイズが5MBを超えています。'
    );
  }

  var buildingId = requireRecordId_(safe.buildingId, 'buildingId');
  var visitId = requireRecordId_(safe.visitId, 'visitId');
  var recordDraft = null;
  if (safe.recordDraft !== null && safe.recordDraft !== undefined) {
    if (
      typeof safe.recordDraft !== 'object' ||
      Array.isArray(safe.recordDraft)
    ) {
      throw createApiError_(
        'VALIDATION_ERROR',
        'recordDraftがJSONオブジェクトではありません。'
      );
    }
    recordDraft = normalizeBeginRecordPayload_(
      safe.recordDraft.requestId,
      safe.recordDraft
    );
    if (
      recordDraft.buildingId !== buildingId ||
      recordDraft.visitId !== visitId
    ) {
      throw createApiError_(
        'CONFLICT',
        'recordDraftと写真の建物・訪問IDが一致しません。'
      );
    }
  }

  if (
    safe.finalizeAfterUpload !== undefined &&
    typeof safe.finalizeAfterUpload !== 'boolean'
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'finalizeAfterUploadが真偽値ではありません。'
    );
  }

  return {
    requestId: requireRecordRequestId_(requestId),
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    visitId: requireRecordId_(safe.visitId, 'visitId'),
    photoId: requireRecordId_(safe.photoId, 'photoId'),
    fileName: requireRecordString_(safe, 'fileName'),
    mimeType: mimeType,
    byteSize: byteSize,
    base64Data: requireRecordString_(safe, 'base64Data'),
    takenAt: requireIsoDate_(safe.takenAt, 'takenAt'),
    latitude: requireLatitude_(safe.latitude),
    longitude: requireLongitude_(safe.longitude),
    accuracyM: optionalNonNegativeNumber_(safe.accuracyM, 'accuracyM'),
    locationSource: requireLocationSource_(safe.locationSource),
    displayOrder: requirePositiveInteger_(
      safe.displayOrder,
      'displayOrder'
    ),
    recordDraft: recordDraft,
    finalizeAfterUpload: safe.finalizeAfterUpload === true
  };
}

function normalizeFinalizeRecordPayload_(requestId, payload) {
  var safe = requireRecordPayloadObject_(payload);
  return {
    requestId: requireRecordRequestId_(requestId),
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    visitId: requireRecordId_(safe.visitId, 'visitId')
  };
}

function ensureRecordBuilding_(spreadsheet, payload) {
  var existing = findSheetRecordById_(
    spreadsheet,
    'Buildings',
    'buildingId',
    payload.buildingId
  );
  var now = new Date();

  if (payload.buildingMode === 'new') {
    if (existing !== null) {
      if (sheetBoolean_(existing.object.isDeleted)) {
        throw createApiError_(
          'CONFLICT',
          '削除済みの建物IDは利用できません。'
        );
      }
      return { created: false, record: existing };
    }

    var folder = createRecordBuildingFolder_(payload.buildingId);
    var row = [
      payload.buildingId,
      payload.buildingName,
      normalizeBuildingSearchName_(payload.buildingName),
      payload.latitude,
      payload.longitude,
      '',
      JSON.stringify(payload.designTagIds),
      JSON.stringify(payload.salesTagIds),
      JSON.stringify(payload.constructionTagIds),
      folder.getId(),
      '',
      now,
      now,
      false
    ];
    appendSheetRow_(spreadsheet, 'Buildings', row);
    return { created: true, record: null };
  }

  if (existing === null || sheetBoolean_(existing.object.isDeleted)) {
    throw createApiError_(
      'NOT_FOUND',
      '選択した建物が見つかりませんでした。'
    );
  }

  var values = existing.values.slice();
  values[6] = JSON.stringify(mergeStringArrays_(
    sheetStringArray_(values[6], 'designTags'),
    payload.designTagIds
  ));
  values[7] = JSON.stringify(mergeStringArrays_(
    sheetStringArray_(values[7], 'salesTags'),
    payload.salesTagIds
  ));
  values[8] = JSON.stringify(mergeStringArrays_(
    sheetStringArray_(values[8], 'constructionTags'),
    payload.constructionTagIds
  ));

  if (isBlankSheetCell_(values[3]) || isBlankSheetCell_(values[4])) {
    values[3] = payload.latitude;
    values[4] = payload.longitude;
  }
  if (isBlankSheetCell_(values[9])) {
    values[9] = createRecordBuildingFolder_(payload.buildingId).getId();
  }
  values[12] = now;
  updateSheetRecord_(
    spreadsheet,
    'Buildings',
    existing.rowNumber,
    values
  );
  return { created: false, record: existing };
}

function ensureRecordVisit_(spreadsheet, payload) {
  var existing = findSheetRecordById_(
    spreadsheet,
    'Visits',
    'visitId',
    payload.visitId
  );
  if (existing !== null) {
    if (String(existing.object.buildingId) !== payload.buildingId) {
      throw createApiError_(
        'CONFLICT',
        'visitIdが別の建物で使用されています。'
      );
    }
    return { created: false, record: existing };
  }

  var now = new Date();
  var row = [
    payload.visitId,
    payload.buildingId,
    payload.visitedAt,
    JSON.stringify(payload.triggerTagIds),
    payload.impression,
    payload.latitude,
    payload.longitude,
    payload.accuracyM === null ? '' : payload.accuracyM,
    payload.locationSource,
    'draft',
    payload.expectedPhotoCount,
    now,
    now,
    false
  ];
  appendSheetRow_(spreadsheet, 'Visits', row);
  return { created: true, record: null };
}

function validateRecordTagIds_(spreadsheet, payload) {
  var tags = readSheetObjects_(spreadsheet, 'Tags');
  var byId = {};
  tags.forEach(function(tag) {
    byId[String(tag.tagId)] = tag;
  });

  validateTagIdsWithIndex_(payload.designTagIds, 'design', byId);
  validateTagIdsWithIndex_(payload.salesTagIds, 'sales', byId);
  validateTagIdsWithIndex_(
    payload.constructionTagIds,
    'construction',
    byId
  );
  validateTagIdsWithIndex_(payload.triggerTagIds, 'trigger', byId);
}

function validateTagIdsWithIndex_(tagIds, expectedType, byId) {
  tagIds.forEach(function(tagId) {
    var tag = byId[tagId];
    if (!tag || String(tag.tagType) !== expectedType) {
      throw createApiError_(
        'VALIDATION_ERROR',
        'タグの種類またはIDが正しくありません。'
      );
    }
    if (!sheetBoolean_(tag.isActive)) {
      throw createApiError_(
        'CONFLICT',
        '無効化されたタグは新しい記録へ追加できません。'
      );
    }
  });
}

function getRecordBuildingFolder_(buildingRecord, buildingId) {
  var folderId = optionalSheetString_(buildingRecord.object.driveFolderId);
  if (folderId !== null) {
    try {
      return DriveApp.getFolderById(folderId);
    } catch (error) {
      throw createApiError_(
        'INTERNAL_ERROR',
        '建物の保存フォルダへアクセスできません。'
      );
    }
  }

  var folder = createRecordBuildingFolder_(buildingId);
  var values = buildingRecord.values.slice();
  values[9] = folder.getId();
  values[12] = new Date();
  updateSheetRecord_(
    getDataSpreadsheet_(),
    'Buildings',
    buildingRecord.rowNumber,
    values
  );
  return folder;
}

function createRecordBuildingFolder_(buildingId) {
  var root = getDriveSpikeFolder_();
  var folders = root.getFoldersByName(buildingId);
  if (folders.hasNext()) {
    return folders.next();
  }
  return root.createFolder(buildingId);
}

function normalizeBuildingSearchName_(buildingName) {
  return String(buildingName)
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\s\u3000]+/g, '');
}

function mergeStringArrays_(currentValues, additionalValues) {
  var seen = {};
  var result = [];
  currentValues.concat(additionalValues).forEach(function(value) {
    var text = String(value).trim();
    if (text !== '' && !seen[text]) {
      seen[text] = true;
      result.push(text);
    }
  });
  return result;
}

function requireActiveSheetRecord_(spreadsheet, sheetName, idField, id) {
  var record = findSheetRecordById_(
    spreadsheet,
    sheetName,
    idField,
    id
  );
  if (record === null || sheetBoolean_(record.object.isDeleted)) {
    throw createApiError_(
      'NOT_FOUND',
      sheetName + 'の対象データが見つかりませんでした。'
    );
  }
  return record;
}

function findSheetRecordById_(spreadsheet, sheetName, idField, id) {
  var definition = findSheetDefinition_(sheetName);
  var fieldIndex = definition.headers.indexOf(idField);
  var sheet = spreadsheet.getSheetByName(sheetName);
  if (sheet === null || fieldIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'シートの定義が正しくありません。'
    );
  }

  var lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    return null;
  }

  var target = String(id).trim();
  var match = sheet
    .getRange(2, fieldIndex + 1, lastRow - 1, 1)
    .createTextFinder(target)
    .matchEntireCell(true)
    .matchCase(true)
    .useRegularExpression(false)
    .findNext();
  if (match === null) {
    return null;
  }

  var rowNumber = match.getRow();
  var values = sheet
    .getRange(rowNumber, 1, 1, definition.headers.length)
    .getValues()[0];
  var object = {};
  definition.headers.forEach(function(header, columnIndex) {
    object[header] = values[columnIndex];
  });

  return {
    rowNumber: rowNumber,
    values: values,
    object: object
  };
}

function readSheetRecordsByField_(
  spreadsheet,
  sheetName,
  fieldName,
  expectedValue
) {
  var definition = findSheetDefinition_(sheetName);
  var fieldIndex = definition.headers.indexOf(fieldName);
  var sheet = spreadsheet.getSheetByName(sheetName);
  if (sheet === null || fieldIndex < 0) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'シートの定義が正しくありません。'
    );
  }

  var lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    return [];
  }

  return sheet
    .getRange(2, 1, lastRow - 1, definition.headers.length)
    .getValues()
    .map(function(values, index) {
      var object = {};
      definition.headers.forEach(function(header, columnIndex) {
        object[header] = values[columnIndex];
      });
      return {
        rowNumber: index + 2,
        values: values,
        object: object
      };
    })
    .filter(function(record) {
      return String(record.values[fieldIndex]).trim()
        === String(expectedValue).trim();
    });
}

function appendSheetRow_(spreadsheet, sheetName, row) {
  var definition = findSheetDefinition_(sheetName);
  if (row.length !== definition.headers.length) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'へ保存する列数が一致しません。'
    );
  }
  var sheet = spreadsheet.getSheetByName(sheetName);
  if (sheet === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'シートがありません。'
    );
  }
  sheet
    .getRange(sheet.getLastRow() + 1, 1, 1, row.length)
    .setValues([row]);
}

function updateSheetRecord_(spreadsheet, sheetName, rowNumber, values) {
  var definition = findSheetDefinition_(sheetName);
  if (values.length !== definition.headers.length) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'を更新する列数が一致しません。'
    );
  }
  var sheet = spreadsheet.getSheetByName(sheetName);
  if (sheet === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'シートがありません。'
    );
  }
  sheet
    .getRange(rowNumber, 1, 1, values.length)
    .setValues([values]);
}

function getRequestResult_(spreadsheet, requestId, action) {
  var record = findSheetRecordById_(
    spreadsheet,
    'Requests',
    'requestId',
    requestId
  );
  if (record === null) {
    return null;
  }

  if (String(record.object.action) !== action) {
    throw createApiError_(
      'CONFLICT',
      '同じrequestIdが別の処理で使用されています。'
    );
  }

  try {
    return JSON.parse(String(record.object.result));
  } catch (error) {
    throw createApiError_(
      'INTERNAL_ERROR',
      '保存済みのAPI結果を読み取れませんでした。'
    );
  }
}

function appendRequestResult_(
  spreadsheet,
  requestId,
  action,
  result,
  relatedIds,
  assumeAbsent
) {
  if (!assumeAbsent) {
    var existing = findSheetRecordById_(
      spreadsheet,
      'Requests',
      'requestId',
      requestId
    );
    if (existing !== null) {
      return;
    }
  }
  appendSheetRow_(spreadsheet, 'Requests', [
    requestId,
    action,
    JSON.stringify(result),
    JSON.stringify(relatedIds),
    '',
    new Date()
  ]);
}

function photoResultFromSheetRecord_(record, reused) {
  return {
    photoId: String(record.object.photoId),
    storageFileId: String(record.object.storageFileId),
    byteSize: Number(record.object.byteSize),
    displayOrder: Number(record.object.displayOrder),
    reused: reused,
    stage: '3-4B'
  };
}

function validateExistingPhotoRecord_(record, payload) {
  if (
    String(record.object.buildingId) !== payload.buildingId ||
    String(record.object.visitId) !== payload.visitId
  ) {
    throw createApiError_(
      'CONFLICT',
      'photoIdが別の記録で使用されています。'
    );
  }
}

function requireRecordPayloadObject_(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'payloadがJSONオブジェクトではありません。'
    );
  }
  return payload;
}

function requireRecordRequestId_(requestId) {
  var result = getOptionalString(requestId);
  if (result === null || !/^[A-Za-z0-9_-]{8,120}$/.test(result)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'requestIdの形式が正しくありません。'
    );
  }
  return result;
}

function requireRecordId_(value, fieldName) {
  var result = getOptionalString(value);
  if (result === null || !/^[A-Za-z0-9_-]{8,120}$/.test(result)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'の形式が正しくありません。'
    );
  }
  return result;
}

function requireRecordString_(object, fieldName) {
  var value = getOptionalString(object[fieldName]);
  if (value === null) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'を指定してください。'
    );
  }
  return value;
}

function optionalLimitedString_(value, maxLength) {
  var result = getOptionalString(value);
  if (result === null) {
    return null;
  }
  if (Array.from(result).length > maxLength) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '文字数の上限を超えています。'
    );
  }
  return result;
}

function requireStringArray_(value, fieldName) {
  if (!Array.isArray(value)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'が配列ではありません。'
    );
  }
  var seen = {};
  var result = [];
  value.forEach(function(item) {
    var text = getOptionalString(item);
    if (text === null) {
      throw createApiError_(
        'VALIDATION_ERROR',
        fieldName + 'に空の値が含まれています。'
      );
    }
    if (!seen[text]) {
      seen[text] = true;
      result.push(text);
    }
  });
  return result;
}

function requirePositiveInteger_(value, fieldName) {
  var number = Number(value);
  if (!isFinite(number) || number <= 0 || Math.floor(number) !== number) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'が正の整数ではありません。'
    );
  }
  return number;
}

function requireIsoDate_(value, fieldName) {
  var text = getOptionalString(value);
  if (text === null) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'を指定してください。'
    );
  }
  var result = new Date(text);
  if (isNaN(result.getTime())) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'が日時形式ではありません。'
    );
  }
  return result;
}

function requireLatitude_(value) {
  var number = Number(value);
  if (!isFinite(number) || number < -90 || number > 90) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'latitudeが正しくありません。'
    );
  }
  return number;
}

function requireLongitude_(value) {
  var number = Number(value);
  if (!isFinite(number) || number < -180 || number > 180) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'longitudeが正しくありません。'
    );
  }
  return number;
}

function optionalNonNegativeNumber_(value, fieldName) {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  var number = Number(value);
  if (!isFinite(number) || number < 0) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'が正しくありません。'
    );
  }
  return number;
}

function requireLocationSource_(value) {
  var result = getOptionalString(value);
  if (result === null || RECORD_LOCATION_SOURCES.indexOf(result) < 0) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'locationSourceが正しくありません。'
    );
  }
  return result;
}

/**
 * Apps Scriptエディタから本保存の一連処理を確認する。
 * テストデータは最後に削除する。
 */
function testRecordFlow() {
  setupDataSpreadsheet();
  setupDriveSpikeStorage();

  var suffix = String(new Date().getTime());
  var buildingId = 'test-building-' + suffix;
  var visitId = 'test-visit-' + suffix;
  var photoId = 'test-photo-' + suffix;
  var recordRequestId = 'test-record-' + suffix;
  var uploadRequestId = 'test-upload-' + suffix;
  var authContext = {
    subject: 'apps-script-editor-test',
    email: 'editor-test@example.com'
  };
  var onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  var uploadPayload = {
    buildingId: buildingId,
    visitId: visitId,
    photoId: photoId,
    fileName: 'test.png',
    mimeType: 'image/png',
    byteSize: Utilities.base64Decode(onePixelPng).length,
    base64Data: onePixelPng,
    takenAt: new Date().toISOString(),
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 10,
    locationSource: 'gps',
    displayOrder: 1,
    finalizeAfterUpload: true,
    recordDraft: {
      requestId: recordRequestId,
      buildingMode: 'new',
      buildingId: buildingId,
      visitId: visitId,
      buildingName: 'API高速保存テスト建物',
      designTagIds: [],
      salesTagIds: [],
      constructionTagIds: [],
      visitedAt: new Date().toISOString(),
      triggerTagIds: [],
      impression: 'API高速保存テスト',
      latitude: 35.681236,
      longitude: 139.767125,
      accuracyM: 10,
      locationSource: 'gps',
      expectedPhotoCount: 1
    }
  };

  try {
    var save = handleUploadPhoto(
      uploadRequestId,
      uploadPayload,
      authContext
    );
    var retry = handleUploadPhoto(
      uploadRequestId,
      uploadPayload,
      authContext
    );
    var saveData = JSON.parse(save.getContent()).data;
    var retryData = JSON.parse(retry.getContent()).data;

    if (!saveData || saveData.recordCompleted !== true) {
      throw createApiError_(
        'INTERNAL_ERROR',
        '1回の通信で記録を確定できませんでした。'
      );
    }
    if (!retryData || retryData.reused !== true) {
      throw createApiError_(
        'INTERNAL_ERROR',
        '同じrequestIdの再送結果を再利用できませんでした。'
      );
    }

    console.log('fastSave: ' + save.getContent());
    console.log('retry: ' + retry.getContent());
  } finally {
    cleanupRecordFlowTest_(
      buildingId,
      visitId,
      photoId,
      [uploadRequestId]
    );
  }
}

function cleanupRecordFlowTest_(
  buildingId,
  visitId,
  photoId,
  requestIds
) {
  var spreadsheet = getDataSpreadsheet_();
  deleteMatchingSheetRows_(spreadsheet, 'Photos', 'photoId', [photoId]);
  deleteMatchingSheetRows_(spreadsheet, 'Visits', 'visitId', [visitId]);
  deleteMatchingSheetRows_(
    spreadsheet,
    'Buildings',
    'buildingId',
    [buildingId]
  );
  deleteMatchingSheetRows_(
    spreadsheet,
    'Requests',
    'requestId',
    requestIds
  );

  var root = getDriveSpikeFolder_();
  var folders = root.getFoldersByName(buildingId);
  while (folders.hasNext()) {
    folders.next().setTrashed(true);
  }
}

function deleteMatchingSheetRows_(
  spreadsheet,
  sheetName,
  fieldName,
  expectedValues
) {
  var records = [];
  expectedValues.forEach(function(value) {
    records = records.concat(readSheetRecordsByField_(
      spreadsheet,
      sheetName,
      fieldName,
      value
    ));
  });
  records
    .sort(function(left, right) {
      return right.rowNumber - left.rowNumber;
    })
    .forEach(function(record) {
      var sheet = spreadsheet.getSheetByName(sheetName);
      sheet.deleteRow(record.rowNumber);
    });
}
