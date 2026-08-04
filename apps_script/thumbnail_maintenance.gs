var THUMBNAIL_MAINTENANCE_ROOT_FOLDER_NAME_ = '_thumbnails';
var THUMBNAIL_MAINTENANCE_BATCH_SIZE_ = 5;
var THUMBNAIL_MAINTENANCE_MAX_RUNTIME_MS_ = 4 * 60 * 1000;
var THUMBNAIL_MAINTENANCE_MAX_BYTES_ = 512 * 1024;
var THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_ =
  'building-record-thumbnail-maintenance-next-row';
var THUMBNAIL_MAINTENANCE_STATE_PROPERTY_ =
  'building-record-thumbnail-maintenance-state';
var THUMBNAIL_MAINTENANCE_CREATED_PROPERTY_ =
  'building-record-thumbnail-maintenance-created';
var THUMBNAIL_MAINTENANCE_FAILED_PROPERTY_ =
  'building-record-thumbnail-maintenance-failed';
var THUMBNAIL_MAINTENANCE_STARTED_AT_PROPERTY_ =
  'building-record-thumbnail-maintenance-started-at';
var THUMBNAIL_MAINTENANCE_ALLOWED_MIME_TYPES_ = {
  'image/jpeg': '.jpg',
  'image/png': '.png'
};

/**
 * Drive APIが元写真のサムネイルを取得できることを、書込みなしで確認する。
 * prepareFullThumbnailRegenerationより先に実行する。
 */
function testThumbnailMaintenancePreview() {
  setupDataSpreadsheet();

  var context = getThumbnailMaintenanceSheetContext_();
  var target = findFirstThumbnailMaintenanceTarget_(context);
  if (target === null) {
    console.log(
      '確認対象の写真がありません。Photosシートに有効な写真が必要です。'
    );
    return;
  }

  var fetched = fetchDriveGeneratedThumbnail_(
    target.storageFileId,
    target.photoId
  );

  console.log(JSON.stringify({
    ok: true,
    photoId: target.photoId,
    buildingId: target.buildingId,
    sourceMimeType: fetched.sourceMimeType,
    thumbnailMimeType: fetched.mimeType,
    thumbnailByteSize: fetched.byteSize,
    message: 'Drive APIからサムネイルを取得できました。'
  }));
}

/**
 * 全件再生成の準備を行う。
 *
 * 変更対象:
 * - PhotosシートのthumbnailFileId列のデータ部分だけを空欄にする。
 * - 設定済みルートフォルダ直下の_thumbnailsフォルダだけをごみ箱へ移す。
 * - 元写真、Buildings、Visits、Photos行そのものは変更しない。
 */
function prepareFullThumbnailRegeneration() {
  setupDataSpreadsheet();

  var context = getThumbnailMaintenanceSheetContext_();
  var dataRowCount = Math.max(context.lastRow - 1, 0);
  if (dataRowCount > 0) {
    context.sheet
      .getRange(
        2,
        context.columns.thumbnailFileId + 1,
        dataRowCount,
        1
      )
      .clearContent();
  }

  var rootFolder = getDriveSpikeFolder_();
  var thumbnailRoots = rootFolder.getFoldersByName(
    THUMBNAIL_MAINTENANCE_ROOT_FOLDER_NAME_
  );
  var trashedFolderCount = 0;
  while (thumbnailRoots.hasNext()) {
    thumbnailRoots.next().setTrashed(true);
    trashedFolderCount += 1;
  }

  clearThumbnailMaintenanceFolderCache_(context);

  var properties = PropertiesService.getScriptProperties();
  properties.setProperties({
    'building-record-thumbnail-maintenance-next-row': '2',
    'building-record-thumbnail-maintenance-state': 'prepared',
    'building-record-thumbnail-maintenance-created': '0',
    'building-record-thumbnail-maintenance-failed': '0',
    'building-record-thumbnail-maintenance-started-at':
      new Date().toISOString()
  });

  var refreshedContext = getThumbnailMaintenanceSheetContext_();
  var status = getThumbnailRegenerationStatus_(refreshedContext);
  var result = {
    ok: true,
    stage: '5-2C',
    clearedPhotoRows: dataRowCount,
    trashedThumbnailRootFolders: trashedFolderCount,
    nextRow: 2,
    status: status,
    message:
      'サムネイル再生成の準備が完了しました。'
      + 'regenerateNextThumbnailBatchを実行してください。'
  };
  console.log(JSON.stringify(result));
  return result;
}

/**
 * Photosシートを上から確認し、最大5枚ずつサムネイルを再生成する。
 * 何度実行しても、thumbnailFileIdが入った行は再処理しない。
 */
function regenerateNextThumbnailBatch() {
  setupDataSpreadsheet();

  var context = getThumbnailMaintenanceSheetContext_();
  var properties = PropertiesService.getScriptProperties();
  var cursor = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_)
  );
  if (!Number.isFinite(cursor) || cursor < 2) {
    cursor = 2;
  }

  var startedAt = Date.now();
  var attempted = 0;
  var created = 0;
  var skipped = 0;
  var failed = 0;
  var errors = [];
  var nextRow = cursor;
  var reachedEnd = false;

  for (var rowNumber = cursor; rowNumber <= context.lastRow; rowNumber += 1) {
    if (
      attempted >= THUMBNAIL_MAINTENANCE_BATCH_SIZE_ ||
      Date.now() - startedAt >= THUMBNAIL_MAINTENANCE_MAX_RUNTIME_MS_
    ) {
      nextRow = rowNumber;
      break;
    }

    nextRow = rowNumber + 1;
    var target = getThumbnailMaintenanceTarget_(context, rowNumber);
    if (target === null) {
      skipped += 1;
      properties.setProperty(
        THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_,
        String(nextRow)
      );
      continue;
    }

    if (target.thumbnailFileId !== null) {
      skipped += 1;
      properties.setProperty(
        THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_,
        String(nextRow)
      );
      continue;
    }

    attempted += 1;
    try {
      var saved = generateAndSaveLegacyThumbnail_(target);
      context.sheet
        .getRange(
          rowNumber,
          context.columns.thumbnailFileId + 1
        )
        .setValue(saved.fileId);
      SpreadsheetApp.flush();
      created += 1;
    } catch (error) {
      failed += 1;
      errors.push({
        rowNumber: rowNumber,
        photoId: target.photoId,
        message: String(error && error.message ? error.message : error)
      });
      console.error(
        'Thumbnail regeneration failed. row='
        + rowNumber
        + ' photoId='
        + target.photoId
        + ' '
        + error
      );
    }

    properties.setProperty(
      THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_,
      String(nextRow)
    );
  }

  if (nextRow > context.lastRow) {
    reachedEnd = true;
  }

  var cumulativeCreated = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_CREATED_PROPERTY_)
  );
  var cumulativeFailed = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_FAILED_PROPERTY_)
  );
  if (!Number.isFinite(cumulativeCreated)) {
    cumulativeCreated = 0;
  }
  if (!Number.isFinite(cumulativeFailed)) {
    cumulativeFailed = 0;
  }
  cumulativeCreated += created;
  cumulativeFailed += failed;

  properties.setProperty(
    THUMBNAIL_MAINTENANCE_CREATED_PROPERTY_,
    String(cumulativeCreated)
  );
  properties.setProperty(
    THUMBNAIL_MAINTENANCE_FAILED_PROPERTY_,
    String(cumulativeFailed)
  );
  properties.setProperty(
    THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_,
    String(nextRow)
  );

  var refreshedContext = getThumbnailMaintenanceSheetContext_();
  var status = getThumbnailRegenerationStatus_(refreshedContext);
  var state = 'running';
  if (reachedEnd && status.remaining === 0) {
    state = 'complete';
  } else if (reachedEnd) {
    state = 'complete_with_missing';
  }
  properties.setProperty(
    THUMBNAIL_MAINTENANCE_STATE_PROPERTY_,
    state
  );

  var result = {
    ok: failed === 0,
    stage: '5-2C',
    state: state,
    attempted: attempted,
    created: created,
    skipped: skipped,
    failed: failed,
    nextRow: nextRow,
    cumulativeCreated: cumulativeCreated,
    cumulativeFailed: cumulativeFailed,
    status: status,
    errors: errors
  };
  console.log(JSON.stringify(result));
  return result;
}

/**
 * 失敗・未処理行だけを再確認するため、カーソルを先頭へ戻す。
 * 作成済みthumbnailFileIdとDriveファイルは残す。
 */
function restartMissingThumbnailRegeneration() {
  var properties = PropertiesService.getScriptProperties();
  properties.setProperty(
    THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_,
    '2'
  );
  properties.setProperty(
    THUMBNAIL_MAINTENANCE_STATE_PROPERTY_,
    'retrying_missing'
  );

  var result = {
    ok: true,
    stage: '5-2C',
    nextRow: 2,
    message:
      '未生成行の再確認を開始できます。'
      + 'regenerateNextThumbnailBatchを実行してください。'
  };
  console.log(JSON.stringify(result));
  return result;
}

/**
 * 現在の進捗をログへ表示する。
 */
function getThumbnailRegenerationStatus() {
  setupDataSpreadsheet();
  var context = getThumbnailMaintenanceSheetContext_();
  var properties = PropertiesService.getScriptProperties();
  var status = getThumbnailRegenerationStatus_(context);
  status.state =
    properties.getProperty(THUMBNAIL_MAINTENANCE_STATE_PROPERTY_)
    || 'not_prepared';
  status.nextRow = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_CURSOR_PROPERTY_)
    || '2'
  );
  status.cumulativeCreated = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_CREATED_PROPERTY_)
    || '0'
  );
  status.cumulativeFailed = Number(
    properties.getProperty(THUMBNAIL_MAINTENANCE_FAILED_PROPERTY_)
    || '0'
  );
  status.startedAt =
    properties.getProperty(THUMBNAIL_MAINTENANCE_STARTED_AT_PROPERTY_);

  console.log(JSON.stringify(status));
  return status;
}

function generateAndSaveLegacyThumbnail_(target) {
  var fetched = fetchDriveGeneratedThumbnail_(
    target.storageFileId,
    target.photoId
  );
  var folder = getRecordBuildingThumbnailFolder_(
    target.buildingId,
    false
  );

  var existing = findThumbnailMaintenanceFile_(
    folder,
    target.photoId
  );
  if (existing !== null) {
    return {
      fileId: existing.getId(),
      reused: true,
      byteSize: existing.getSize()
    };
  }

  var extension =
    THUMBNAIL_MAINTENANCE_ALLOWED_MIME_TYPES_[fetched.mimeType];
  var fileName = target.photoId + extension;
  var blob = fetched.blob.copyBlob().setName(fileName);
  var file = folder.createFile(blob);
  file.setDescription(
    'Building record regenerated thumbnail. photoId='
    + target.photoId
  );

  return {
    fileId: file.getId(),
    reused: false,
    byteSize: fetched.byteSize
  };
}

function fetchDriveGeneratedThumbnail_(storageFileId, photoId) {
  var metadata;
  try {
    metadata = Drive.Files.get(storageFileId, {
      fields:
        'id,name,mimeType,trashed,hasThumbnail,thumbnailLink'
    });
  } catch (error) {
    throw new Error(
      '元写真のDrive情報を取得できませんでした。photoId='
      + photoId
      + ' '
      + error
    );
  }

  if (metadata.trashed) {
    throw new Error(
      '元写真がごみ箱にあります。photoId=' + photoId
    );
  }
  if (!metadata.hasThumbnail || !metadata.thumbnailLink) {
    throw new Error(
      'Google Driveがサムネイルを生成していません。photoId='
      + photoId
    );
  }

  var response = UrlFetchApp.fetch(metadata.thumbnailLink, {
    method: 'get',
    headers: {
      Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
    },
    followRedirects: true,
    muteHttpExceptions: true
  });
  var responseCode = response.getResponseCode();
  if (responseCode < 200 || responseCode >= 300) {
    throw new Error(
      'Driveサムネイルの取得に失敗しました。'
      + 'photoId='
      + photoId
      + ' status='
      + responseCode
    );
  }

  var blob = response.getBlob();
  var mimeType = String(blob.getContentType() || '')
    .split(';')[0]
    .trim()
    .toLowerCase();
  if (!THUMBNAIL_MAINTENANCE_ALLOWED_MIME_TYPES_[mimeType]) {
    throw new Error(
      'Driveサムネイルが未対応形式です。'
      + 'photoId='
      + photoId
      + ' mimeType='
      + mimeType
    );
  }

  var bytes = blob.getBytes();
  if (bytes.length === 0) {
    throw new Error(
      'Driveサムネイルが空です。photoId=' + photoId
    );
  }
  if (bytes.length > THUMBNAIL_MAINTENANCE_MAX_BYTES_) {
    throw new Error(
      'Driveサムネイルが表示上限を超えています。'
      + 'photoId='
      + photoId
      + ' bytes='
      + bytes.length
    );
  }

  return {
    blob: blob,
    mimeType: mimeType,
    byteSize: bytes.length,
    sourceMimeType: metadata.mimeType
  };
}

function getThumbnailMaintenanceSheetContext_() {
  var spreadsheet = getDataSpreadsheet_();
  var sheet = spreadsheet.getSheetByName('Photos');
  if (sheet === null) {
    throw new Error('Photosシートが見つかりません。');
  }

  var values = sheet.getDataRange().getValues();
  if (values.length === 0) {
    throw new Error('Photosシートの見出しがありません。');
  }

  var headers = values[0].map(function(value) {
    return String(value).trim();
  });
  var columns = {
    photoId: headers.indexOf('photoId'),
    buildingId: headers.indexOf('buildingId'),
    storageProvider: headers.indexOf('storageProvider'),
    storageFileId: headers.indexOf('storageFileId'),
    thumbnailFileId: headers.indexOf('thumbnailFileId'),
    isDeleted: headers.indexOf('isDeleted')
  };

  Object.keys(columns).forEach(function(key) {
    if (columns[key] < 0) {
      throw new Error(
        'Photosシートに必要な列がありません: ' + key
      );
    }
  });

  return {
    spreadsheet: spreadsheet,
    sheet: sheet,
    values: values,
    columns: columns,
    lastRow: values.length
  };
}

function findFirstThumbnailMaintenanceTarget_(context) {
  for (var rowNumber = 2; rowNumber <= context.lastRow; rowNumber += 1) {
    var target = getThumbnailMaintenanceTarget_(context, rowNumber);
    if (target !== null) {
      return target;
    }
  }
  return null;
}

function getThumbnailMaintenanceTarget_(context, rowNumber) {
  var row = context.values[rowNumber - 1];
  if (!row) {
    return null;
  }

  var isDeleted = thumbnailMaintenanceBoolean_(
    row[context.columns.isDeleted]
  );
  var storageProvider = thumbnailMaintenanceString_(
    row[context.columns.storageProvider]
  );
  var photoId = thumbnailMaintenanceString_(
    row[context.columns.photoId]
  );
  var buildingId = thumbnailMaintenanceString_(
    row[context.columns.buildingId]
  );
  var storageFileId = thumbnailMaintenanceString_(
    row[context.columns.storageFileId]
  );
  var thumbnailFileId = thumbnailMaintenanceString_(
    row[context.columns.thumbnailFileId]
  );

  if (
    isDeleted ||
    storageProvider !== 'google_drive' ||
    photoId === null ||
    buildingId === null ||
    storageFileId === null
  ) {
    return null;
  }

  return {
    rowNumber: rowNumber,
    photoId: photoId,
    buildingId: buildingId,
    storageFileId: storageFileId,
    thumbnailFileId: thumbnailFileId
  };
}

function getThumbnailRegenerationStatus_(context) {
  var eligible = 0;
  var generated = 0;
  var remaining = 0;

  for (var rowNumber = 2; rowNumber <= context.lastRow; rowNumber += 1) {
    var target = getThumbnailMaintenanceTarget_(context, rowNumber);
    if (target === null) {
      continue;
    }
    eligible += 1;
    if (target.thumbnailFileId === null) {
      remaining += 1;
    } else {
      generated += 1;
    }
  }

  return {
    eligible: eligible,
    generated: generated,
    remaining: remaining
  };
}

function clearThumbnailMaintenanceFolderCache_(context) {
  var keysByValue = {};
  for (var rowNumber = 2; rowNumber <= context.lastRow; rowNumber += 1) {
    var row = context.values[rowNumber - 1];
    var buildingId = thumbnailMaintenanceString_(
      row[context.columns.buildingId]
    );
    if (buildingId !== null) {
      keysByValue[recordThumbnailFolderCacheKey_(buildingId)] = true;
    }
  }

  var keys = Object.keys(keysByValue);
  if (keys.length > 0) {
    CacheService.getScriptCache().removeAll(keys);
  }
}

function findThumbnailMaintenanceFile_(folder, photoId) {
  var candidates = [
    photoId + '.jpg',
    photoId + '.png'
  ];
  for (var index = 0; index < candidates.length; index += 1) {
    var files = folder.getFilesByName(candidates[index]);
    if (files.hasNext()) {
      return files.next();
    }
  }
  return null;
}

function thumbnailMaintenanceString_(value) {
  if (value === null || value === undefined) {
    return null;
  }
  var text = String(value).trim();
  return text === '' ? null : text;
}

function thumbnailMaintenanceBoolean_(value) {
  if (value === true) {
    return true;
  }
  var text = String(value || '').trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'yes';
}
