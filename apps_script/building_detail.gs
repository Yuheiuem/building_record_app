var BUILDING_DETAIL_MAX_PHOTO_BYTES_ = 5 * 1024 * 1024;
var BUILDING_DETAIL_ALLOWED_MIME_TYPES_ = {
  'image/jpeg': true,
  'image/png': true
};

/**
 * 建物情報、完了済み訪問、写真メタデータ、参照中タグを返す。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetBuildingDetail(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var buildingId = getBuildingDetailRequiredId_(payload, 'buildingId');
  var spreadsheet = getDataSpreadsheet_();
  var building = findBuildingDetailBuilding_(spreadsheet, buildingId);

  var visits = readSheetObjects_(spreadsheet, 'Visits')
    .map(normalizeBuildingDetailVisitRow_)
    .filter(function(visit) {
      return visit.buildingId === buildingId &&
        !visit.isDeleted &&
        visit.status === 'completed';
    })
    .sort(function(left, right) {
      return String(right.visitedAt).localeCompare(String(left.visitedAt));
    });

  var visitIds = {};
  visits.forEach(function(visit) {
    visitIds[visit.visitId] = true;
  });

  var photos = readSheetObjects_(spreadsheet, 'Photos')
    .map(normalizeBuildingDetailPhotoRow_)
    .filter(function(photo) {
      return photo.buildingId === buildingId &&
        !photo.isDeleted &&
        visitIds[photo.visitId] === true;
    })
    .sort(function(left, right) {
      if (building.coverPhotoId) {
        if (left.photoId === building.coverPhotoId) {
          return -1;
        }
        if (right.photoId === building.coverPhotoId) {
          return 1;
        }
      }

      var timeDifference = String(right.takenAt || right.createdAt || '')
        .localeCompare(String(left.takenAt || left.createdAt || ''));
      if (timeDifference !== 0) {
        return timeDifference;
      }
      return left.displayOrder - right.displayOrder;
    });

  var referencedTagIds = collectBuildingDetailTagIds_(building, visits);
  var tags = readSheetObjects_(spreadsheet, 'Tags')
    .map(normalizeTagRow_)
    .filter(function(tag) {
      return referencedTagIds[tag.tagId] === true;
    })
    .sort(function(left, right) {
      var typeDifference = supportedTagTypeIndex_(left.tagType) -
        supportedTagTypeIndex_(right.tagType);
      if (typeDifference !== 0) {
        return typeDifference;
      }
      if (left.displayOrder !== right.displayOrder) {
        return left.displayOrder - right.displayOrder;
      }
      return left.tagName.localeCompare(right.tagName, 'ja');
    });

  visits.forEach(function(visit) {
    delete visit.isDeleted;
  });
  photos.forEach(function(photo) {
    delete photo.isDeleted;
  });

  return createApiResponse(
    true,
    requestId,
    {
      schemaVersion: DATA_SCHEMA_VERSION,
      stage: '4-2',
      building: building,
      visits: visits,
      photos: photos,
      tags: tags,
      counts: {
        visits: visits.length,
        photos: photos.length
      }
    },
    null,
    null
  );
}

/**
 * PhotosシートのphotoIdを起点に、非公開Drive画像を認証付きで返す。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetPhotoData(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);

  var photoId = getBuildingDetailRequiredId_(payload, 'photoId');
  var spreadsheet = getDataSpreadsheet_();
  var photoRecord = findBuildingDetailSheetRecord_(
    spreadsheet,
    'Photos',
    'photoId',
    photoId
  );

  if (photoRecord === null || sheetBoolean_(photoRecord.isDeleted)) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }

  var storageProvider = optionalSheetString_(photoRecord.storageProvider);
  var storageFileId = optionalSheetString_(photoRecord.storageFileId);
  var buildingId = optionalSheetString_(photoRecord.buildingId);

  if (storageProvider !== 'google_drive' || storageFileId === null) {
    throw createApiError_('NOT_FOUND', '写真の保存先を確認できませんでした。');
  }
  if (buildingId === null) {
    throw createApiError_('INTERNAL_ERROR', '写真にbuildingIdがありません。');
  }

  var building = findBuildingDetailBuilding_(spreadsheet, buildingId);
  var expectedFolderId = optionalSheetString_(building.driveFolderId);
  if (expectedFolderId === null) {
    throw createApiError_('INTERNAL_ERROR', '建物のDriveフォルダが未設定です。');
  }

  var file;
  try {
    file = DriveApp.getFileById(storageFileId);
  } catch (error) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }

  if (
    file.isTrashed() ||
    !isBuildingDetailFileInFolder_(file, expectedFolderId)
  ) {
    throw createApiError_('NOT_FOUND', '写真が見つかりませんでした。');
  }

  var mimeType = file.getMimeType();
  if (!BUILDING_DETAIL_ALLOWED_MIME_TYPES_[mimeType]) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '保存ファイルが対応画像形式ではありません。'
    );
  }

  var bytes = file.getBlob().getBytes();
  if (bytes.length > BUILDING_DETAIL_MAX_PHOTO_BYTES_) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '保存画像が表示上限を超えています。'
    );
  }

  return createApiResponse(
    true,
    requestId,
    {
      photoId: photoId,
      fileName: optionalSheetString_(photoRecord.fileName) || file.getName(),
      mimeType: mimeType,
      byteSize: bytes.length,
      base64Data: Utilities.base64Encode(bytes),
      stage: '4-2'
    },
    null,
    null
  );
}

/**
 * Buildingsシートの有効な1件を取得する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} buildingId
 * @return {Object}
 */
function findBuildingDetailBuilding_(spreadsheet, buildingId) {
  var buildingRecord = findBuildingDetailSheetRecord_(
    spreadsheet,
    'Buildings',
    'buildingId',
    buildingId
  );

  if (buildingRecord === null || sheetBoolean_(buildingRecord.isDeleted)) {
    throw createApiError_('NOT_FOUND', '建物が見つかりませんでした。');
  }

  return normalizeBuildingRow_(buildingRecord);
}

/**
 * Visitsシートの行を詳細API形式へ変換する。
 *
 * @param {Object} row
 * @return {Object}
 */
function normalizeBuildingDetailVisitRow_(row) {
  var visitId = optionalSheetString_(row.visitId);
  var buildingId = optionalSheetString_(row.buildingId);
  var visitedAt = sheetDateTime_(row.visitedAt) || sheetDateTime_(row.createdAt);

  if (visitId === null || buildingId === null || visitedAt === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Visitsシートに必須項目がない行があります。'
    );
  }

  return {
    visitId: visitId,
    buildingId: buildingId,
    visitedAt: visitedAt,
    triggerTags: sheetStringArray_(row.triggerTags, 'triggerTags'),
    impression: optionalSheetString_(row.impression) || '',
    latitude: optionalSheetNumber_(row.latitude),
    longitude: optionalSheetNumber_(row.longitude),
    accuracyM: optionalSheetNumber_(row.accuracyM),
    locationSource: optionalSheetString_(row.locationSource) || '',
    status: optionalSheetString_(row.status) || '',
    expectedPhotoCount: optionalSheetNumber_(row.expectedPhotoCount) || 0,
    createdAt: sheetDateTime_(row.createdAt),
    updatedAt: sheetDateTime_(row.updatedAt),
    isDeleted: sheetBoolean_(row.isDeleted)
  };
}

/**
 * Photosシートの行を詳細API形式へ変換する。
 * storageFileIdは一覧応答へ含めず、photoIdで再取得する。
 *
 * @param {Object} row
 * @return {Object}
 */
function normalizeBuildingDetailPhotoRow_(row) {
  var photoId = optionalSheetString_(row.photoId);
  var buildingId = optionalSheetString_(row.buildingId);
  var visitId = optionalSheetString_(row.visitId);
  var fileName = optionalSheetString_(row.fileName);
  var mimeType = optionalSheetString_(row.mimeType);

  if (
    photoId === null ||
    buildingId === null ||
    visitId === null ||
    fileName === null ||
    mimeType === null
  ) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Photosシートに必須項目がない行があります。'
    );
  }

  return {
    photoId: photoId,
    buildingId: buildingId,
    visitId: visitId,
    fileName: fileName,
    mimeType: mimeType,
    byteSize: optionalSheetNumber_(row.byteSize) || 0,
    width: optionalSheetNumber_(row.width),
    height: optionalSheetNumber_(row.height),
    takenAt: sheetDateTime_(row.takenAt),
    latitude: optionalSheetNumber_(row.latitude),
    longitude: optionalSheetNumber_(row.longitude),
    accuracyM: optionalSheetNumber_(row.accuracyM),
    locationSource: optionalSheetString_(row.locationSource) || '',
    displayOrder: optionalSheetNumber_(row.displayOrder) || 0,
    createdAt: sheetDateTime_(row.createdAt),
    isDeleted: sheetBoolean_(row.isDeleted)
  };
}

/**
 * 建物と訪問が参照しているタグIDを集合化する。
 * 無効化済みタグも名称表示のため返却対象に含める。
 *
 * @param {Object} building
 * @param {Object[]} visits
 * @return {Object<string, boolean>}
 */
function collectBuildingDetailTagIds_(building, visits) {
  var result = {};
  var tagIds = []
    .concat(building.designTags || [])
    .concat(building.salesTags || [])
    .concat(building.constructionTags || []);

  visits.forEach(function(visit) {
    tagIds = tagIds.concat(visit.triggerTags || []);
  });

  tagIds.forEach(function(tagId) {
    if (tagId) {
      result[tagId] = true;
    }
  });

  return result;
}

/**
 * 指定フィールドが一致する先頭行を取得する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} sheetName
 * @param {string} fieldName
 * @param {string} expectedValue
 * @return {Object|null}
 */
function findBuildingDetailSheetRecord_(
  spreadsheet,
  sheetName,
  fieldName,
  expectedValue
) {
  if (typeof findSheetRecordById_ === 'function') {
    var indexedRecord = findSheetRecordById_(
      spreadsheet,
      sheetName,
      fieldName,
      expectedValue
    );
    return indexedRecord === null ? null : indexedRecord.object;
  }

  var records = readSheetObjects_(spreadsheet, sheetName);

  for (var i = 0; i < records.length; i += 1) {
    if (optionalSheetString_(records[i][fieldName]) === expectedValue) {
      return records[i];
    }
  }

  return null;
}

/**
 * Driveファイルの直接の親フォルダを確認する。
 *
 * @param {GoogleAppsScript.Drive.File} file
 * @param {string} expectedFolderId
 * @return {boolean}
 */
function isBuildingDetailFileInFolder_(file, expectedFolderId) {
  var parents = file.getParents();

  while (parents.hasNext()) {
    if (parents.next().getId() === expectedFolderId) {
      return true;
    }
  }

  return false;
}

/**
 * payloadからIDを取得する。
 *
 * @param {Object} payload
 * @param {string} fieldName
 * @return {string}
 */
function getBuildingDetailRequiredId_(payload, fieldName) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'payloadがJSONオブジェクトではありません。'
    );
  }

  var value = getOptionalString(payload[fieldName]);
  if (value === null || !/^[A-Za-z0-9_-]{8,200}$/.test(value)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'の形式が正しくありません。'
    );
  }

  return value;
}

/**
 * 既存の最初の建物を使い、詳細取得と画像取得を確認する。
 * データがない場合は何も作成せず終了する。
 */
function testGetBuildingDetail() {
  setupDataSpreadsheet();

  var spreadsheet = getDataSpreadsheet_();
  var buildingRows = readSheetObjects_(spreadsheet, 'Buildings')
    .filter(function(row) {
      return !sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.buildingId) !== null;
    });

  if (buildingRows.length === 0) {
    console.log('確認対象の建物がありません。先に記録を1件保存してください。');
    return;
  }

  var buildingId = optionalSheetString_(buildingRows[0].buildingId);
  var authContext = {
    subject: 'apps-script-editor-test',
    email: 'editor-test@example.com'
  };
  var detailResponse = handleGetBuildingDetail(
    'apps-script-editor-building-detail-test',
    { buildingId: buildingId },
    authContext
  );
  console.log('detail: ' + detailResponse.getContent());

  var photoRows = readSheetObjects_(spreadsheet, 'Photos')
    .filter(function(row) {
      return optionalSheetString_(row.buildingId) === buildingId &&
        !sheetBoolean_(row.isDeleted) &&
        optionalSheetString_(row.photoId) !== null;
    });

  if (photoRows.length === 0) {
    console.log('この建物には写真がありません。詳細取得のみ確認しました。');
    return;
  }

  var photoResponse = handleGetPhotoData(
    'apps-script-editor-photo-data-test',
    { photoId: optionalSheetString_(photoRows[0].photoId) },
    authContext
  );
  var photoResult = JSON.parse(photoResponse.getContent());
  if (photoResult.data && photoResult.data.base64Data) {
    photoResult.data.base64Length = photoResult.data.base64Data.length;
    delete photoResult.data.base64Data;
  }
  console.log('photo: ' + JSON.stringify(photoResult));
}
