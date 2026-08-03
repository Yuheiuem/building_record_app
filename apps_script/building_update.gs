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
 * Apps Scriptエディタでpayload検証だけを確認する。
 */
function testNormalizeUpdateBuildingLocationPayload() {
  var result = normalizeUpdateBuildingLocationPayload_({
    buildingId: 'building-12345678',
    latitude: 35.681236,
    longitude: 139.767125
  });

  console.log(JSON.stringify(result));
}
