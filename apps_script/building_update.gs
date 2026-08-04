/**
 * 建物の代表座標だけを更新する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUpdateBuildingLocation(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeUpdateBuildingLocationPayload_(payload);
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
    var definition = findSheetDefinition_('Buildings');
    var latitudeIndex = definition.headers.indexOf('latitude');
    var longitudeIndex = definition.headers.indexOf('longitude');
    var updatedAtIndex = definition.headers.indexOf('updatedAt');
    if (
      latitudeIndex < 0 ||
      longitudeIndex < 0 ||
      updatedAtIndex < 0
    ) {
      throw createApiError_(
        'INTERNAL_ERROR',
        'Buildingsシートの座標列定義が正しくありません。'
      );
    }

    var values = buildingRecord.values.slice();
    values[latitudeIndex] = normalized.latitude;
    values[longitudeIndex] = normalized.longitude;
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
        stage: '5-1B',
        buildingId: normalized.buildingId,
        latitude: normalized.latitude,
        longitude: normalized.longitude
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 建物名、住所、建物タグを更新する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUpdateBuildingInformation(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeUpdateBuildingInformationPayload_(payload);
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

    validateBuildingInformationTagIds_(
      spreadsheet,
      buildingRecord.object,
      normalized
    );

    var definition = findSheetDefinition_('Buildings');
    var buildingNameIndex = definition.headers.indexOf('buildingName');
    var searchNameIndex = definition.headers.indexOf('searchName');
    var addressIndex = definition.headers.indexOf('address');
    var designTagsIndex = definition.headers.indexOf('designTags');
    var salesTagsIndex = definition.headers.indexOf('salesTags');
    var constructionTagsIndex = definition.headers.indexOf(
      'constructionTags'
    );
    var updatedAtIndex = definition.headers.indexOf('updatedAt');

    if (
      buildingNameIndex < 0 ||
      searchNameIndex < 0 ||
      addressIndex < 0 ||
      designTagsIndex < 0 ||
      salesTagsIndex < 0 ||
      constructionTagsIndex < 0 ||
      updatedAtIndex < 0
    ) {
      throw createApiError_(
        'INTERNAL_ERROR',
        'Buildingsシートの建物情報列定義が正しくありません。'
      );
    }

    var values = buildingRecord.values.slice();
    values[buildingNameIndex] = normalized.buildingName;
    values[searchNameIndex] = normalizeBuildingSearchName_(
      normalized.buildingName
    );
    values[addressIndex] = normalized.address || '';
    values[designTagsIndex] = JSON.stringify(normalized.designTagIds);
    values[salesTagsIndex] = JSON.stringify(normalized.salesTagIds);
    values[constructionTagsIndex] = JSON.stringify(
      normalized.constructionTagIds
    );
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
        stage: '5-3A',
        buildingId: normalized.buildingId,
        buildingName: normalized.buildingName,
        address: normalized.address,
        designTagIds: normalized.designTagIds,
        salesTagIds: normalized.salesTagIds,
        constructionTagIds: normalized.constructionTagIds
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 代表座標更新payloadを検証する。
 *
 * @param {Object} payload
 * @return {{buildingId: string, latitude: number, longitude: number}}
 */
function normalizeUpdateBuildingLocationPayload_(payload) {
  var safe = requireRecordPayloadObject_(payload);

  return {
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    latitude: requireLatitude_(safe.latitude),
    longitude: requireLongitude_(safe.longitude)
  };
}

/**
 * 建物情報更新payloadを検証する。
 *
 * @param {Object} payload
 * @return {Object}
 */
function normalizeUpdateBuildingInformationPayload_(payload) {
  var safe = requireRecordPayloadObject_(payload);
  var buildingName = getOptionalString(safe.buildingName);
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

  var address = getOptionalString(safe.address);
  if (address !== null && Array.from(address).length > 200) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '住所は200文字以内で入力してください。'
    );
  }

  return {
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    buildingName: buildingName,
    address: address,
    designTagIds: uniqueBuildingUpdateTagIds_(
      requireStringArray_(safe.designTagIds, 'designTagIds')
    ),
    salesTagIds: uniqueBuildingUpdateTagIds_(
      requireStringArray_(safe.salesTagIds, 'salesTagIds')
    ),
    constructionTagIds: uniqueBuildingUpdateTagIds_(
      requireStringArray_(safe.constructionTagIds, 'constructionTagIds')
    )
  };
}

/**
 * 選択されたタグが存在し、種別が一致していることを確認する。
 * 無効タグは、その建物が更新前から参照している場合だけ維持できる。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} buildingObject
 * @param {Object} normalized
 */
function validateBuildingInformationTagIds_(
  spreadsheet,
  buildingObject,
  normalized
) {
  var tagsById = {};
  readSheetObjects_(spreadsheet, 'Tags')
    .map(normalizeTagRow_)
    .forEach(function(tag) {
      tagsById[tag.tagId] = tag;
    });

  validateBuildingInformationTagType_(
    normalized.designTagIds,
    'design',
    sheetStringArray_(buildingObject.designTags, 'designTags'),
    tagsById
  );
  validateBuildingInformationTagType_(
    normalized.salesTagIds,
    'sales',
    sheetStringArray_(buildingObject.salesTags, 'salesTags'),
    tagsById
  );
  validateBuildingInformationTagType_(
    normalized.constructionTagIds,
    'construction',
    sheetStringArray_(buildingObject.constructionTags, 'constructionTags'),
    tagsById
  );
}

/**
 * @param {string[]} tagIds
 * @param {string} expectedType
 * @param {string[]} currentTagIds
 * @param {Object<string, Object>} tagsById
 */
function validateBuildingInformationTagType_(
  tagIds,
  expectedType,
  currentTagIds,
  tagsById
) {
  tagIds.forEach(function(tagId) {
    var tag = tagsById[tagId];
    if (!tag) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '選択したタグが見つかりませんでした。'
      );
    }
    if (tag.tagType !== expectedType) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '選択したタグの種別が正しくありません。'
      );
    }
    if (!tag.isActive && currentTagIds.indexOf(tagId) < 0) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '無効化されたタグは新しく選択できません。'
      );
    }
  });
}

/**
 * @param {string[]} values
 * @return {string[]}
 */
function uniqueBuildingUpdateTagIds_(values) {
  var seen = {};
  var result = [];
  values.forEach(function(value) {
    if (!seen[value]) {
      seen[value] = true;
      result.push(value);
    }
  });
  return result;
}

/**
 * Apps Scriptエディタで代表座標payload検証だけを確認する。
 */
function testNormalizeUpdateBuildingLocationPayload() {
  var result = normalizeUpdateBuildingLocationPayload_({
    buildingId: 'building-12345678',
    latitude: 35.681236,
    longitude: 139.767125
  });

  console.log(JSON.stringify(result));
}

/**
 * Apps Scriptエディタで建物情報payload検証だけを確認する。
 */
function testNormalizeUpdateBuildingInformationPayload() {
  var result = normalizeUpdateBuildingInformationPayload_({
    buildingId: 'building-12345678',
    buildingName: '更新後の建物名',
    address: '東京都千代田区丸の内1-1',
    designTagIds: ['tag-design-1234'],
    salesTagIds: ['tag-sales-1234'],
    constructionTagIds: ['tag-construction-1234']
  });

  console.log(JSON.stringify(result));
}
