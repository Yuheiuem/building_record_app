/**
 * 起動時に必要な建物・タグ・件数を返す。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetBootstrapData(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var spreadsheet = getDataSpreadsheet_();

  var buildings = readSheetObjects_(spreadsheet, 'Buildings')
    .map(normalizeBuildingRow_)
    .filter(function(building) {
      return !building.isDeleted;
    });

  var tags = readSheetObjects_(spreadsheet, 'Tags')
    .map(normalizeTagRow_)
    .filter(function(tag) {
      return tag.isActive;
    })
    .sort(function(a, b) {
      var typeDifference = supportedTagTypeIndex_(a.tagType)
        - supportedTagTypeIndex_(b.tagType);
      if (typeDifference !== 0) {
        return typeDifference;
      }
      if (a.displayOrder !== b.displayOrder) {
        return a.displayOrder - b.displayOrder;
      }
      return a.tagName.localeCompare(b.tagName, 'ja');
    });

  var visits = readSheetObjects_(spreadsheet, 'Visits')
    .filter(function(row) {
      return !sheetBoolean_(row.isDeleted);
    });

  var photos = readSheetObjects_(spreadsheet, 'Photos')
    .filter(function(row) {
      return !sheetBoolean_(row.isDeleted);
    });

  return createApiResponse(
    true,
    requestId,
    {
      schemaVersion: DATA_SCHEMA_VERSION,
      stage: '2-2',
      buildings: buildings,
      tags: tags,
      counts: {
        buildings: buildings.length,
        visits: visits.length,
        photos: photos.length,
        tags: tags.length
      }
    },
    null,
    null
  );
}

/**
 * Buildingsシートの1行をAPI形式へ変換する。
 *
 * @param {Object} row
 * @return {Object}
 */
function normalizeBuildingRow_(row) {
  var buildingId = optionalSheetString_(row.buildingId);
  var buildingName = optionalSheetString_(row.buildingName);

  if (buildingId === null || buildingName === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'BuildingsシートにbuildingIdまたはbuildingNameがない行があります。'
    );
  }

  return {
    buildingId: buildingId,
    buildingName: buildingName,
    searchName: optionalSheetString_(row.searchName) || '',
    latitude: optionalSheetNumber_(row.latitude),
    longitude: optionalSheetNumber_(row.longitude),
    address: optionalSheetString_(row.address),
    designTags: sheetStringArray_(row.designTags, 'designTags'),
    salesTags: sheetStringArray_(row.salesTags, 'salesTags'),
    constructionTags: sheetStringArray_(
      row.constructionTags,
      'constructionTags'
    ),
    driveFolderId: optionalSheetString_(row.driveFolderId),
    coverPhotoId: optionalSheetString_(row.coverPhotoId),
    createdAt: sheetDateTime_(row.createdAt),
    updatedAt: sheetDateTime_(row.updatedAt),
    isDeleted: sheetBoolean_(row.isDeleted)
  };
}

/**
 * Tagsシートの1行をAPI形式へ変換する。
 *
 * @param {Object} row
 * @return {Object}
 */
function normalizeTagRow_(row) {
  var tagId = optionalSheetString_(row.tagId);
  var tagType = optionalSheetString_(row.tagType);
  var tagName = optionalSheetString_(row.tagName);

  if (tagId === null || tagType === null || tagName === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Tagsシートに必須項目がない行があります。'
    );
  }

  requireSupportedTagType_(tagType);

  var normalizedName = optionalSheetString_(row.normalizedName)
    || normalizeTagName_(tagName);

  return {
    tagId: tagId,
    tagType: tagType,
    tagName: tagName,
    normalizedName: normalizedName,
    displayOrder: optionalSheetNumber_(row.displayOrder) || 0,
    isActive: sheetBoolean_(row.isActive),
    createdAt: sheetDateTime_(row.createdAt),
    updatedAt: sheetDateTime_(row.updatedAt)
  };
}

/**
 * Apps Scriptエディタからタグを含む起動データを確認する。
 */
function testGetBootstrapData() {
  setupDataSpreadsheet();

  var response = handleGetBootstrapData(
    'apps-script-editor-bootstrap-test',
    {},
    {
      subject: 'apps-script-editor-test',
      email: 'editor-test@example.com'
    }
  );

  console.log(response.getContent());
}
