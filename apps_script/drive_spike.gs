var DRIVE_ROOT_FOLDER_ID_PROPERTY = 'DRIVE_ROOT_FOLDER_ID';
var DRIVE_SPIKE_FOLDER_NAME = 'building-record-app-storage';
var DRIVE_SPIKE_MAX_PHOTO_BYTES = 2 * 1024 * 1024;
var DRIVE_SPIKE_ALLOWED_MIME_TYPES = {
  'image/jpeg': true,
  'image/png': true
};

/**
 * 段階0-4用の非公開保存フォルダを作り、Script PropertiesへIDを保存する。
 * Apps Scriptエディタから一度だけ手動実行する。
 */
function setupDriveSpikeStorage() {
  var properties = PropertiesService.getScriptProperties();
  var existingFolderId = getOptionalString(
    properties.getProperty(DRIVE_ROOT_FOLDER_ID_PROPERTY)
  );

  if (existingFolderId !== null) {
    var existingFolder = DriveApp.getFolderById(existingFolderId);
    console.log('既存の保存フォルダを使用します: ' + existingFolder.getId());
    console.log('共有状態: ' + existingFolder.getSharingAccess());
    return;
  }

  var folder = DriveApp.createFolder(DRIVE_SPIKE_FOLDER_NAME);
  properties.setProperty(
    DRIVE_ROOT_FOLDER_ID_PROPERTY,
    folder.getId()
  );

  console.log('保存フォルダを作成しました: ' + folder.getId());
  console.log('共有状態: ' + folder.getSharingAccess());
}

/**
 * 認証済み画像アップロードを処理する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleUploadSpikePhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var normalizedPayload = validateUploadSpikePayload_(payload);
  var folder = getDriveSpikeFolder_();
  var internalFileName = buildDriveSpikeFileName_(
    normalizedPayload.photoId,
    normalizedPayload.mimeType
  );

  var existingFiles = folder.getFilesByName(internalFileName);
  if (existingFiles.hasNext()) {
    var existingFile = existingFiles.next();
    return createApiResponse(
      true,
      requestId,
      buildUploadResponseData_(existingFile, true),
      null,
      null
    );
  }

  var bytes;
  try {
    bytes = Utilities.base64Decode(normalizedPayload.base64Data);
  } catch (error) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像データが正しいBase64ではありません。'
    );
  }

  if (bytes.length !== normalizedPayload.byteSize) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像データのサイズが申告値と一致しません。'
    );
  }

  if (bytes.length > DRIVE_SPIKE_MAX_PHOTO_BYTES) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像サイズが技術スパイクの上限を超えています。'
    );
  }

  var blob = Utilities.newBlob(
    bytes,
    normalizedPayload.mimeType,
    internalFileName
  );
  var file = folder.createFile(blob);
  file.setDescription(
    'Building record app stage 0-4 spike. photoId=' +
    normalizedPayload.photoId
  );

  return createApiResponse(
    true,
    requestId,
    buildUploadResponseData_(file, false),
    null,
    null
  );
}

/**
 * 認証済み画像再取得を処理する。
 *
 * @param {string|null} requestId
 * @param {Object} payload
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleGetSpikePhoto(requestId, payload, authContext) {
  requireAuthenticatedContext_(authContext);
  var storageFileId = getRequiredPayloadString_(
    payload,
    'storageFileId'
  );

  if (!/^[A-Za-z0-9_-]{10,200}$/.test(storageFileId)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'storageFileIdの形式が正しくありません。'
    );
  }

  var file;
  try {
    file = DriveApp.getFileById(storageFileId);
  } catch (error) {
    throw createApiError_(
      'NOT_FOUND',
      '画像が見つかりませんでした。'
    );
  }

  if (file.isTrashed() || !isFileInDriveSpikeFolder_(file)) {
    throw createApiError_(
      'NOT_FOUND',
      '画像が見つかりませんでした。'
    );
  }

  var mimeType = file.getMimeType();
  if (!DRIVE_SPIKE_ALLOWED_MIME_TYPES[mimeType]) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '保存ファイルが対応画像形式ではありません。'
    );
  }

  var bytes = file.getBlob().getBytes();
  if (bytes.length > DRIVE_SPIKE_MAX_PHOTO_BYTES) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '保存ファイルが技術スパイクの上限を超えています。'
    );
  }

  return createApiResponse(
    true,
    requestId,
    {
      storageFileId: file.getId(),
      fileName: file.getName(),
      mimeType: mimeType,
      byteSize: bytes.length,
      base64Data: Utilities.base64Encode(bytes),
      sharingAccess: String(file.getSharingAccess()),
      stage: '0-4'
    },
    null,
    null
  );
}

/**
 * アップロードpayloadを検証する。
 *
 * @param {Object} payload
 * @return {{photoId: string, mimeType: string, byteSize: number, base64Data: string}}
 */
function validateUploadSpikePayload_(payload) {
  var photoId = getRequiredPayloadString_(payload, 'photoId');
  var mimeType = getRequiredPayloadString_(payload, 'mimeType');
  var base64Data = getRequiredPayloadString_(payload, 'base64Data');
  var byteSize = payload && payload.byteSize;

  if (!/^[A-Za-z0-9_-]{8,100}$/.test(photoId)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'photoIdの形式が正しくありません。'
    );
  }

  if (!DRIVE_SPIKE_ALLOWED_MIME_TYPES[mimeType]) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'JPEGまたはPNGのみ保存できます。'
    );
  }

  if (
    typeof byteSize !== 'number' ||
    !isFinite(byteSize) ||
    byteSize <= 0 ||
    Math.floor(byteSize) !== byteSize
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'byteSizeが正しくありません。'
    );
  }

  if (byteSize > DRIVE_SPIKE_MAX_PHOTO_BYTES) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '画像サイズが技術スパイクの上限を超えています。'
    );
  }

  return {
    photoId: photoId,
    mimeType: mimeType,
    byteSize: byteSize,
    base64Data: base64Data
  };
}

/**
 * Script Propertiesから保存フォルダを取得する。
 *
 * @return {GoogleAppsScript.Drive.Folder}
 */
function getDriveSpikeFolder_() {
  var folderId = getOptionalString(
    PropertiesService
      .getScriptProperties()
      .getProperty(DRIVE_ROOT_FOLDER_ID_PROPERTY)
  );

  if (folderId === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Drive保存先が未設定です。setupDriveSpikeStorageを実行してください。'
    );
  }

  try {
    return DriveApp.getFolderById(folderId);
  } catch (error) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Drive保存先フォルダへアクセスできません。'
    );
  }
}

/**
 * ファイルが段階0-4の保存フォルダ内にあるか確認する。
 *
 * @param {GoogleAppsScript.Drive.File} file
 * @return {boolean}
 */
function isFileInDriveSpikeFolder_(file) {
  var expectedFolderId = getDriveSpikeFolder_().getId();
  var parents = file.getParents();

  while (parents.hasNext()) {
    if (parents.next().getId() === expectedFolderId) {
      return true;
    }
  }

  return false;
}

/**
 * 内部IDを使った保存ファイル名を作る。
 *
 * @param {string} photoId
 * @param {string} mimeType
 * @return {string}
 */
function buildDriveSpikeFileName_(photoId, mimeType) {
  var extension = mimeType === 'image/png' ? '.png' : '.jpg';
  return 'spike_' + photoId + extension;
}

/**
 * アップロード成功応答のdataを作る。
 *
 * @param {GoogleAppsScript.Drive.File} file
 * @param {boolean} duplicate
 * @return {Object}
 */
function buildUploadResponseData_(file, duplicate) {
  return {
    storageFileId: file.getId(),
    fileName: file.getName(),
    mimeType: file.getMimeType(),
    byteSize: file.getSize(),
    duplicate: duplicate,
    sharingAccess: String(file.getSharingAccess()),
    stage: '0-4'
  };
}

/**
 * payloadから必須文字列を取得する。
 *
 * @param {Object} payload
 * @param {string} fieldName
 * @return {string}
 */
function getRequiredPayloadString_(payload, fieldName) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'payloadがJSONオブジェクトではありません。'
    );
  }

  var value = getOptionalString(payload[fieldName]);
  if (value === null) {
    throw createApiError_(
      'VALIDATION_ERROR',
      fieldName + 'がありません。'
    );
  }

  return value;
}
