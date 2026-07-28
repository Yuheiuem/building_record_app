var SPREADSHEET_ID_PROPERTY = 'SPREADSHEET_ID';
var DATA_SPREADSHEET_NAME = 'building-record-app-data';
var DATA_SCHEMA_VERSION = '1.0';

var DATA_SHEET_DEFINITIONS = [
  {
    name: 'Buildings',
    headers: [
      'buildingId',
      'buildingName',
      'searchName',
      'latitude',
      'longitude',
      'address',
      'designTags',
      'salesTags',
      'constructionTags',
      'driveFolderId',
      'coverPhotoId',
      'createdAt',
      'updatedAt',
      'isDeleted'
    ]
  },
  {
    name: 'Visits',
    headers: [
      'visitId',
      'buildingId',
      'visitedAt',
      'triggerTags',
      'impression',
      'latitude',
      'longitude',
      'accuracyM',
      'locationSource',
      'status',
      'expectedPhotoCount',
      'createdAt',
      'updatedAt',
      'isDeleted'
    ]
  },
  {
    name: 'Photos',
    headers: [
      'photoId',
      'buildingId',
      'visitId',
      'storageProvider',
      'storageFileId',
      'thumbnailFileId',
      'fileName',
      'mimeType',
      'byteSize',
      'width',
      'height',
      'takenAt',
      'latitude',
      'longitude',
      'accuracyM',
      'locationSource',
      'displayOrder',
      'createdAt',
      'isDeleted'
    ]
  },
  {
    name: 'Tags',
    headers: [
      'tagId',
      'tagType',
      'tagName',
      'normalizedName',
      'displayOrder',
      'isActive',
      'createdAt',
      'updatedAt'
    ]
  },
  {
    name: 'Requests',
    headers: [
      'requestId',
      'action',
      'result',
      'relatedIds',
      'errorCode',
      'createdAt'
    ]
  }
];

/**
 * データ保存用Spreadsheetと必要なシートを作成する。
 * Apps Scriptエディタから最初に一度実行する。
 */
function setupDataSpreadsheet() {
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);

  try {
    var properties = PropertiesService.getScriptProperties();
    var existingId = getOptionalString(
      properties.getProperty(SPREADSHEET_ID_PROPERTY)
    );
    var spreadsheet;

    if (existingId !== null) {
      spreadsheet = openDataSpreadsheetById_(existingId);
      ensureDataSchema_(spreadsheet);
      console.log('既存のSpreadsheetを使用します。');
      console.log('Spreadsheet ID: ' + spreadsheet.getId());
      console.log('Schema version: ' + DATA_SCHEMA_VERSION);
      return;
    }

    spreadsheet = SpreadsheetApp.create(DATA_SPREADSHEET_NAME);
    spreadsheet.setSpreadsheetTimeZone('Asia/Tokyo');
    initializeNewSpreadsheet_(spreadsheet);

    properties.setProperty(
      SPREADSHEET_ID_PROPERTY,
      spreadsheet.getId()
    );

    console.log('データ保存用Spreadsheetを作成しました。');
    console.log('Spreadsheet ID: ' + spreadsheet.getId());
    console.log('Schema version: ' + DATA_SCHEMA_VERSION);
  } finally {
    lock.releaseLock();
  }
}

/**
 * Script Propertiesに保存されたSpreadsheetを開く。
 *
 * @return {GoogleAppsScript.Spreadsheet.Spreadsheet}
 */
function getDataSpreadsheet_() {
  var spreadsheetId = getOptionalString(
    PropertiesService
      .getScriptProperties()
      .getProperty(SPREADSHEET_ID_PROPERTY)
  );

  if (spreadsheetId === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Spreadsheetが未設定です。setupDataSpreadsheetを実行してください。'
    );
  }

  var spreadsheet = openDataSpreadsheetById_(spreadsheetId);
  ensureDataSchema_(spreadsheet);
  return spreadsheet;
}

/**
 * Spreadsheet IDから開く。
 *
 * @param {string} spreadsheetId
 * @return {GoogleAppsScript.Spreadsheet.Spreadsheet}
 */
function openDataSpreadsheetById_(spreadsheetId) {
  try {
    return SpreadsheetApp.openById(spreadsheetId);
  } catch (error) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'データ保存用Spreadsheetを開けませんでした。'
    );
  }
}

/**
 * 新規Spreadsheetへ全シートを作成する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 */
function initializeNewSpreadsheet_(spreadsheet) {
  var firstDefinition = DATA_SHEET_DEFINITIONS[0];
  var firstSheet = spreadsheet.getSheets()[0];
  firstSheet.setName(firstDefinition.name);
  writeHeaderRow_(firstSheet, firstDefinition.headers);

  for (var i = 1; i < DATA_SHEET_DEFINITIONS.length; i += 1) {
    var definition = DATA_SHEET_DEFINITIONS[i];
    var sheet = spreadsheet.insertSheet(definition.name);
    writeHeaderRow_(sheet, definition.headers);
  }
}

/**
 * 必要なシートとヘッダーがそろっていることを確認する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 */
function ensureDataSchema_(spreadsheet) {
  DATA_SHEET_DEFINITIONS.forEach(function(definition) {
    var sheet = spreadsheet.getSheetByName(definition.name);

    if (sheet === null) {
      sheet = spreadsheet.insertSheet(definition.name);
      writeHeaderRow_(sheet, definition.headers);
      return;
    }

    ensureHeaderRow_(sheet, definition.headers);
  });
}

/**
 * シートのヘッダーを検証する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet
 * @param {string[]} expectedHeaders
 */
function ensureHeaderRow_(sheet, expectedHeaders) {
  if (sheet.getLastRow() === 0) {
    writeHeaderRow_(sheet, expectedHeaders);
    return;
  }

  var actualHeaders = sheet
    .getRange(1, 1, 1, expectedHeaders.length)
    .getValues()[0]
    .map(function(value) {
      return String(value).trim();
    });

  for (var i = 0; i < expectedHeaders.length; i += 1) {
    if (actualHeaders[i] !== expectedHeaders[i]) {
      throw createApiError_(
        'CONFLICT',
        sheet.getName() + 'シートのヘッダーが仕様と一致しません。'
      );
    }
  }

  formatHeaderRow_(sheet, expectedHeaders.length);
}

/**
 * ヘッダー行を書き込む。
 *
 * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet
 * @param {string[]} headers
 */
function writeHeaderRow_(sheet, headers) {
  sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  formatHeaderRow_(sheet, headers.length);
}

/**
 * ヘッダー行の表示を整える。
 *
 * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet
 * @param {number} columnCount
 */
function formatHeaderRow_(sheet, columnCount) {
  sheet.setFrozenRows(1);
  sheet
    .getRange(1, 1, 1, columnCount)
    .setFontWeight('bold')
    .setBackground('#DCEFF2');
}

/**
 * シートの各行を、1行目のヘッダーをキーとするObjectへ変換する。
 *
 * @param {GoogleAppsScript.Spreadsheet.Spreadsheet} spreadsheet
 * @param {string} sheetName
 * @return {Object[]}
 */
function readSheetObjects_(spreadsheet, sheetName) {
  var definition = findSheetDefinition_(sheetName);
  var sheet = spreadsheet.getSheetByName(sheetName);

  if (sheet === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      sheetName + 'シートがありません。'
    );
  }

  var lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    return [];
  }

  var values = sheet
    .getRange(2, 1, lastRow - 1, definition.headers.length)
    .getValues();

  return values
    .filter(function(row) {
      return row.some(function(value) {
        return !isBlankSheetCell_(value);
      });
    })
    .map(function(row) {
      var result = {};
      definition.headers.forEach(function(header, index) {
        result[header] = row[index];
      });
      return result;
    });
}

/**
 * シート定義を取得する。
 *
 * @param {string} sheetName
 * @return {{name: string, headers: string[]}}
 */
function findSheetDefinition_(sheetName) {
  for (var i = 0; i < DATA_SHEET_DEFINITIONS.length; i += 1) {
    if (DATA_SHEET_DEFINITIONS[i].name === sheetName) {
      return DATA_SHEET_DEFINITIONS[i];
    }
  }

  throw createApiError_(
    'INTERNAL_ERROR',
    sheetName + 'のシート定義がありません。'
  );
}

/**
 * 空セルか判定する。
 *
 * @param {*} value
 * @return {boolean}
 */
function isBlankSheetCell_(value) {
  return value === null || value === '';
}

/**
 * セルを任意文字列へ変換する。
 *
 * @param {*} value
 * @return {string|null}
 */
function optionalSheetString_(value) {
  if (value === null || value === undefined) {
    return null;
  }

  var result = String(value).trim();
  return result === '' ? null : result;
}

/**
 * セルを任意数値へ変換する。
 *
 * @param {*} value
 * @return {number|null}
 */
function optionalSheetNumber_(value) {
  if (isBlankSheetCell_(value)) {
    return null;
  }

  var result = Number(value);
  if (!isFinite(result)) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Spreadsheet内に数値として読めない値があります。'
    );
  }

  return result;
}

/**
 * セルをbooleanへ変換する。
 *
 * @param {*} value
 * @return {boolean}
 */
function sheetBoolean_(value) {
  if (value === true || value === 1) {
    return true;
  }

  if (typeof value === 'string') {
    var normalized = value.trim().toLowerCase();
    return normalized === 'true' || normalized === '1';
  }

  return false;
}

/**
 * JSON配列として保存されたセルを文字列配列へ変換する。
 *
 * @param {*} value
 * @param {string} fieldName
 * @return {string[]}
 */
function sheetStringArray_(value, fieldName) {
  if (isBlankSheetCell_(value)) {
    return [];
  }

  if (Array.isArray(value)) {
    return value
      .map(function(item) { return String(item).trim(); })
      .filter(function(item) { return item !== ''; });
  }

  var parsed;
  try {
    parsed = JSON.parse(String(value));
  } catch (error) {
    throw createApiError_(
      'INTERNAL_ERROR',
      fieldName + 'がJSON配列ではありません。'
    );
  }

  if (!Array.isArray(parsed)) {
    throw createApiError_(
      'INTERNAL_ERROR',
      fieldName + 'がJSON配列ではありません。'
    );
  }

  return parsed
    .map(function(item) { return String(item).trim(); })
    .filter(function(item) { return item !== ''; });
}

/**
 * セルの日付をISO 8601文字列へ変換する。
 *
 * @param {*} value
 * @return {string|null}
 */
function sheetDateTime_(value) {
  if (isBlankSheetCell_(value)) {
    return null;
  }

  if (Object.prototype.toString.call(value) === '[object Date]') {
    return Utilities.formatDate(
      value,
      'Asia/Tokyo',
      "yyyy-MM-dd'T'HH:mm:ss"
    ) + '+09:00';
  }

  return optionalSheetString_(value);
}
