/**
 * 訪問日時、きっかけタグ、感想、訪問位置を更新する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUpdateVisitInformation(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var normalizedRequestId = requireRecordRequestId_(requestId);
  var normalized = normalizeUpdateVisitInformationPayload_(payload);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    throw createApiError_(
      'RATE_LIMIT',
      '別の保存処理が実行中です。少し待ってから、もう一度送信してください。'
    );
  }

  try {
    var spreadsheet = getDataSpreadsheet_();
    requireActiveSheetRecord_(
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

    if (
      optionalSheetString_(visitRecord.object.buildingId) !==
      normalized.buildingId
    ) {
      throw createApiError_(
        'CONFLICT',
        '指定した訪問記録は、この建物に所属していません。'
      );
    }

    validateVisitInformationTagIds_(
      spreadsheet,
      visitRecord.object,
      normalized.triggerTagIds
    );

    var definition = findSheetDefinition_('Visits');
    var visitedAtIndex = definition.headers.indexOf('visitedAt');
    var triggerTagsIndex = definition.headers.indexOf('triggerTags');
    var impressionIndex = definition.headers.indexOf('impression');
    var latitudeIndex = definition.headers.indexOf('latitude');
    var longitudeIndex = definition.headers.indexOf('longitude');
    var accuracyMIndex = definition.headers.indexOf('accuracyM');
    var locationSourceIndex = definition.headers.indexOf('locationSource');
    var updatedAtIndex = definition.headers.indexOf('updatedAt');

    if (
      visitedAtIndex < 0 ||
      triggerTagsIndex < 0 ||
      impressionIndex < 0 ||
      latitudeIndex < 0 ||
      longitudeIndex < 0 ||
      accuracyMIndex < 0 ||
      locationSourceIndex < 0 ||
      updatedAtIndex < 0
    ) {
      throw createApiError_(
        'INTERNAL_ERROR',
        'Visitsシートの訪問情報列定義が正しくありません。'
      );
    }

    var values = visitRecord.values.slice();
    values[visitedAtIndex] = normalized.visitedAt;
    values[triggerTagsIndex] = JSON.stringify(normalized.triggerTagIds);
    values[impressionIndex] = normalized.impression;
    values[latitudeIndex] = normalized.latitude === null
      ? ''
      : normalized.latitude;
    values[longitudeIndex] = normalized.longitude === null
      ? ''
      : normalized.longitude;
    values[accuracyMIndex] = normalized.accuracyM === null
      ? ''
      : normalized.accuracyM;
    values[locationSourceIndex] = normalized.locationSource;
    values[updatedAtIndex] = new Date();

    updateSheetRecord_(
      spreadsheet,
      'Visits',
      visitRecord.rowNumber,
      values
    );

    return createApiResponse(
      true,
      normalizedRequestId,
      {
        stage: '5-3B',
        buildingId: normalized.buildingId,
        visitId: normalized.visitId,
        visitedAt: normalized.visitedAt.toISOString(),
        triggerTagIds: normalized.triggerTagIds,
        impression: normalized.impression,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        accuracyM: normalized.accuracyM,
        locationSource: normalized.locationSource
      },
      null,
      null
    );
  } finally {
    lock.releaseLock();
  }
}

/**
 * 訪問情報更新payloadを検証する。
 *
 * @param {Object} payload
 * @return {Object}
 */
function normalizeUpdateVisitInformationPayload_(payload) {
  var safe = requireRecordPayloadObject_(payload);
  var impression = optionalLimitedString_(safe.impression, 2000) || '';
  var normalizedLocation = normalizeVisitUpdateLocation_(safe);

  return {
    buildingId: requireRecordId_(safe.buildingId, 'buildingId'),
    visitId: requireRecordId_(safe.visitId, 'visitId'),
    visitedAt: requireIsoDate_(safe.visitedAt, 'visitedAt'),
    triggerTagIds: uniqueVisitUpdateTagIds_(
      requireStringArray_(safe.triggerTagIds, 'triggerTagIds')
    ),
    impression: impression,
    latitude: normalizedLocation.latitude,
    longitude: normalizedLocation.longitude,
    accuracyM: normalizedLocation.accuracyM,
    locationSource: normalizedLocation.locationSource
  };
}

/**
 * 訪問位置は緯度・経度をセットで受け取る。
 * 位置情報がない場合は関連項目を空として扱う。
 *
 * @param {Object} safe
 * @return {Object}
 */
function normalizeVisitUpdateLocation_(safe) {
  var latitudeIsBlank =
    safe.latitude === null ||
    safe.latitude === undefined ||
    safe.latitude === '';
  var longitudeIsBlank =
    safe.longitude === null ||
    safe.longitude === undefined ||
    safe.longitude === '';

  if (latitudeIsBlank && longitudeIsBlank) {
    return {
      latitude: null,
      longitude: null,
      accuracyM: null,
      locationSource: ''
    };
  }
  if (latitudeIsBlank || longitudeIsBlank) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '訪問位置の緯度と経度を両方指定してください。'
    );
  }

  return {
    latitude: requireLatitude_(safe.latitude),
    longitude: requireLongitude_(safe.longitude),
    accuracyM: optionalNonNegativeNumber_(safe.accuracyM, 'accuracyM'),
    locationSource: requireLocationSource_(safe.locationSource)
  };
}

/**
 * 選択されたきっかけタグを検証する。
 * 無効タグは、その訪問が更新前から参照している場合だけ維持できる。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {Object} visitObject
 * @param {string[]} triggerTagIds
 */
function validateVisitInformationTagIds_(
  spreadsheet,
  visitObject,
  triggerTagIds
) {
  var tagsById = {};
  readSheetObjects_(spreadsheet, 'Tags')
    .map(normalizeTagRow_)
    .forEach(function(tag) {
      tagsById[tag.tagId] = tag;
    });
  var currentTagIds = sheetStringArray_(
    visitObject.triggerTags,
    'triggerTags'
  );

  triggerTagIds.forEach(function(tagId) {
    var tag = tagsById[tagId];
    if (!tag) {
      throw createApiError_(
        'VALIDATION_ERROR',
        '選択したきっかけタグが見つかりませんでした。'
      );
    }
    if (tag.tagType !== 'trigger') {
      throw createApiError_(
        'VALIDATION_ERROR',
        '選択したタグはきっかけタグではありません。'
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
function uniqueVisitUpdateTagIds_(values) {
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
 * Apps Scriptエディタで訪問情報payload検証だけを確認する。
 */
function testNormalizeUpdateVisitInformationPayload() {
  var result = normalizeUpdateVisitInformationPayload_({
    buildingId: 'building-12345678',
    visitId: 'visit-12345678',
    visitedAt: '2026-08-04T14:30:00+09:00',
    triggerTagIds: ['tag-trigger-1234'],
    impression: '更新後の感想',
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: null,
    locationSource: 'manual'
  });

  console.log(JSON.stringify({
    buildingId: result.buildingId,
    visitId: result.visitId,
    visitedAt: result.visitedAt.toISOString(),
    triggerTagIds: result.triggerTagIds,
    impression: result.impression,
    latitude: result.latitude,
    longitude: result.longitude,
    accuracyM: result.accuracyM,
    locationSource: result.locationSource
  }));
}
