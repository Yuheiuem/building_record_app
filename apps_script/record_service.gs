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

    validateTagIds_(
      spreadsheet,
      normalized.designTagIds,
      'design'
    );
    validateTagIds_(
      spreadsheet,
      normalized.salesTagIds,
      'sales'
    );
    validateTagIds_(
      spreadsheet,
      normalized.constructionTagIds,
      'construction'
    );
    validateTagIds_(
      spreadsheet,
      normalized.triggerTagIds,
      'trigger'
    );

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
      }
    );

    return createApiResponse(true, requestId, result, null, null);
  } finally {
    lock.releaseLock();
  }
}

/**
 * 写真を1枚ずつ非公開Driveへ保存し、Photosシートへ登録する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUploadPhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalized = normalizeUploadPhotoPayload_(requestId, payload);
  var spreadsheet = getDataSpreadsheet_();
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    var cached = getRequestResult_(
      spreadsheet,
      normalized.requestId,
      'uploadPhoto'
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

    var existingPhoto = findSheetRecordById_(
      spreadsheet,
      'Photos',
      'photoId',
      normalized.photoId
    );
    if (existingPhoto !== null) {
      validateExistingPhotoRecord_(existingPhoto, normalized);
      var existingResult = photoResultFromSheetRecord_(
        existingPhoto,
        true
      );
      appendRequestResult_(
        spreadsheet,
        normalized.requestId,
        'uploadPhoto',
        existingResult,
        {
          buildingId: normalized.buildingId,
          visitId: normalized.visitId,
          photoId: normalized.photoId
        }
      );
      return createApiResponse(
        true,
        requestId,
        existingResult,
        null,
        null
      );
    }

    var bytes;
    try {
      bytes = Utilities.base64Decode(normalized.base64Data);
    } catch (error) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '画像データが正しいBase64ではありません。'
      );
    }

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
    appendSheetRow_(spreadsheet, 'Photos', photoRow);

    var result = {
      photoId: normalized.photoId,
      storageFileId: file.getId(),
      byteSize: bytes.length,
      displayOrder: normalized.displayOrder,
      reused: reusedFile,
      stage: '3-4B'
    };

    appendRequestResult_(
      spreadsheet,
      normalized.requestId,
      'uploadPhoto',
      result,
      {
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
        photoId: normalized.photoId
      }
    );

    return createApiResponse(true, requestId, result, null, null);
  } finally {
    lock.releaseLock();
  }
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
      }
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
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    visitId: requireRecordId_(safe.visitId, 'visitId'),
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
    )
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

function validateTagIds_(spreadsheet, tagIds, expectedType) {
  if (tagIds.length === 0) {
    return;
  }

  var tags = readSheetObjects_(spreadsheet, 'Tags');
  var byId = {};
  tags.forEach(function(tag) {
    byId[String(tag.tagId)] = tag;
  });

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
  var records = readSheetRecordsByField_(
    spreadsheet,
    sheetName,
    idField,
    id
  );
  return records.length === 0 ? null : records[0];
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
  var records = readSheetRecordsByField_(
    spreadsheet,
    'Requests',
    'requestId',
    requestId
  );
  if (records.length === 0) {
    return null;
  }

  var record = records[0];
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
  relatedIds
) {
  var existing = readSheetRecordsByField_(
    spreadsheet,
    'Requests',
    'requestId',
    requestId
  );
  if (existing.length > 0) {
    return;
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
  var beginRequestId = 'test-begin-' + suffix;
  var uploadRequestId = 'test-upload-' + suffix;
  var finalizeRequestId = 'test-finalize-' + suffix;
  var authContext = {
    subject: 'apps-script-editor-test',
    email: 'editor-test@example.com'
  };

  try {
    var begin = handleBeginRecord(
      beginRequestId,
      {
        buildingMode: 'new',
        buildingId: buildingId,
        visitId: visitId,
        buildingName: 'API保存テスト建物',
        designTagIds: [],
        salesTagIds: [],
        constructionTagIds: [],
        visitedAt: new Date().toISOString(),
        triggerTagIds: [],
        impression: 'API保存テスト',
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyM: 10,
        locationSource: 'gps',
        expectedPhotoCount: 1
      },
      authContext
    );

    var onePixelPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    var upload = handleUploadPhoto(
      uploadRequestId,
      {
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
        displayOrder: 1
      },
      authContext
    );

    var finalize = handleFinalizeRecord(
      finalizeRequestId,
      {
        buildingId: buildingId,
        visitId: visitId
      },
      authContext
    );

    var beginRetry = handleBeginRecord(
      beginRequestId,
      {
        buildingMode: 'new',
        buildingId: buildingId,
        visitId: visitId,
        buildingName: 'API保存テスト建物',
        designTagIds: [],
        salesTagIds: [],
        constructionTagIds: [],
        visitedAt: new Date().toISOString(),
        triggerTagIds: [],
        impression: 'API保存テスト',
        latitude: 35.681236,
        longitude: 139.767125,
        accuracyM: 10,
        locationSource: 'gps',
        expectedPhotoCount: 1
      },
      authContext
    );
    var uploadRetry = handleUploadPhoto(
      uploadRequestId,
      {
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
        displayOrder: 1
      },
      authContext
    );
    var finalizeRetry = handleFinalizeRecord(
      finalizeRequestId,
      {
        buildingId: buildingId,
        visitId: visitId
      },
      authContext
    );

    var retryResults = [beginRetry, uploadRetry, finalizeRetry]
      .map(function(response) {
        return JSON.parse(response.getContent()).data;
      });
    retryResults.forEach(function(result) {
      if (!result || result.reused !== true) {
        throw createApiError_(
          'INTERNAL_ERROR',
          '同じrequestIdの再送結果を再利用できませんでした。'
        );
      }
    });

    console.log('begin: ' + begin.getContent());
    console.log('upload: ' + upload.getContent());
    console.log('finalize: ' + finalize.getContent());
    console.log('retry: ' + JSON.stringify(retryResults));
  } finally {
    cleanupRecordFlowTest_(
      buildingId,
      visitId,
      photoId,
      [beginRequestId, uploadRequestId, finalizeRequestId]
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
