var SUPPORTED_TAG_TYPES = [
  'trigger',
  'design',
  'sales',
  'construction'
];

/**
 * 初期投入するタグ。
 *
 * 設計・営業タグは、実際の部署名や設計事務所名が未確定のため、
 * この段階では空のままとする。確定後はTagsシートまたは後続UIから追加する。
 * Flutter側にはタグ候補を固定値として持たせない。
 */
var INITIAL_TAG_SEEDS = [
  {
    tagId: 'tag-trigger-sales-work',
    tagType: 'trigger',
    tagName: '営業の仕事',
    displayOrder: 10
  },
  {
    tagId: 'tag-trigger-design-training',
    tagType: 'trigger',
    tagName: '設計研修',
    displayOrder: 20
  },
  {
    tagId: 'tag-trigger-personal-travel',
    tagType: 'trigger',
    tagName: '個人旅行',
    displayOrder: 30
  },
  {
    tagId: 'tag-construction-in-house',
    tagType: 'construction',
    tagName: '当社施工',
    displayOrder: 10
  },
  {
    tagId: 'tag-construction-kajima',
    tagType: 'construction',
    tagName: '鹿島施工',
    displayOrder: 20
  }
];

/**
 * 初期タグをTagsシートへ投入する。
 * 同じtagId、または同じtagType + normalizedNameが存在する場合は重複追加しない。
 * 再実行時は不足・変更された初期タグだけを更新する。
 *
 * @return {{inserted: number, updated: number, unchanged: number, totalSeeds: number}}
 */
function seedInitialTags() {
  setupDataSpreadsheet();

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);

  try {
    var spreadsheet = getDataSpreadsheet_();
    var sheet = spreadsheet.getSheetByName('Tags');
    var definition = findSheetDefinition_('Tags');

    if (sheet === null) {
      throw createApiError_(
        'INTERNAL_ERROR',
        'Tagsシートがありません。'
      );
    }

    var existingRecords = readExistingTagRecords_(
      sheet,
      definition.headers.length
    );
    var byId = {};
    var byNormalizedKey = {};

    existingRecords.forEach(function(record) {
      if (record.tagId !== null) {
        byId[record.tagId] = record;
      }
      if (record.tagType !== null && record.normalizedName !== null) {
        byNormalizedKey[tagNormalizedKey_(
          record.tagType,
          record.normalizedName
        )] = record;
      }
    });

    validateInitialTagSeeds_();

    var now = new Date();
    var rowsToAppend = [];
    var inserted = 0;
    var updated = 0;
    var unchanged = 0;

    INITIAL_TAG_SEEDS.forEach(function(seed) {
      var normalizedSeed = normalizeTagSeed_(seed);
      var normalizedKey = tagNormalizedKey_(
        normalizedSeed.tagType,
        normalizedSeed.normalizedName
      );
      var existing = byId[normalizedSeed.tagId]
        || byNormalizedKey[normalizedKey]
        || null;

      if (existing === null) {
        var newRow = tagSeedRow_(
          normalizedSeed,
          normalizedSeed.tagId,
          now,
          now
        );
        rowsToAppend.push(newRow);
        inserted += 1;

        var pendingRecord = tagRecordFromRow_(
          newRow,
          null
        );
        byId[pendingRecord.tagId] = pendingRecord;
        byNormalizedKey[normalizedKey] = pendingRecord;
        return;
      }

      var desiredTagId = existing.tagId || normalizedSeed.tagId;
      var createdAt = isBlankSheetCell_(existing.values[6])
        ? now
        : existing.values[6];
      var desiredRow = tagSeedRow_(
        normalizedSeed,
        desiredTagId,
        createdAt,
        now
      );

      if (tagSeedRowMatches_(existing.values, desiredRow)) {
        unchanged += 1;
        return;
      }

      sheet
        .getRange(existing.rowNumber, 1, 1, definition.headers.length)
        .setValues([desiredRow]);
      updated += 1;

      var updatedRecord = tagRecordFromRow_(
        desiredRow,
        existing.rowNumber
      );
      byId[updatedRecord.tagId] = updatedRecord;
      byNormalizedKey[normalizedKey] = updatedRecord;
    });

    if (rowsToAppend.length > 0) {
      sheet
        .getRange(
          sheet.getLastRow() + 1,
          1,
          rowsToAppend.length,
          definition.headers.length
        )
        .setValues(rowsToAppend);
    }

    var result = {
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
      totalSeeds: INITIAL_TAG_SEEDS.length
    };

    console.log('初期タグ投入結果: ' + JSON.stringify(result));
    return result;
  } finally {
    lock.releaseLock();
  }
}


/**
 * 初期タグ定義内にIDまたは種類・名前の重複がないことを確認する。
 */
function validateInitialTagSeeds_() {
  var ids = {};
  var normalizedKeys = {};

  INITIAL_TAG_SEEDS.forEach(function(seed) {
    var normalizedSeed = normalizeTagSeed_(seed);
    var normalizedKey = tagNormalizedKey_(
      normalizedSeed.tagType,
      normalizedSeed.normalizedName
    );

    if (ids[normalizedSeed.tagId]) {
      throw createApiError_(
        'DUPLICATE',
        '初期タグ定義のtagIdが重複しています: ' + normalizedSeed.tagId
      );
    }
    if (normalizedKeys[normalizedKey]) {
      throw createApiError_(
        'DUPLICATE',
        '初期タグ定義の種類・名前が重複しています: '
          + normalizedSeed.tagName
      );
    }

    ids[normalizedSeed.tagId] = true;
    normalizedKeys[normalizedKey] = true;
  });
}

/**
 * Tagsシートの既存行を行番号付きで読む。
 *
 * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet
 * @param {number} columnCount
 * @return {Object[]}
 */
function readExistingTagRecords_(sheet, columnCount) {
  var lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    return [];
  }

  return sheet
    .getRange(2, 1, lastRow - 1, columnCount)
    .getValues()
    .map(function(row, index) {
      return tagRecordFromRow_(row, index + 2);
    })
    .filter(function(record) {
      return record.values.some(function(value) {
        return !isBlankSheetCell_(value);
      });
    });
}

/**
 * Tagsシートの行を検索用Recordへ変換する。
 *
 * @param {Array<*>} row
 * @param {number|null} rowNumber
 * @return {Object}
 */
function tagRecordFromRow_(row, rowNumber) {
  var tagType = optionalSheetString_(row[1]);
  var tagName = optionalSheetString_(row[2]);
  var normalizedName = optionalSheetString_(row[3]);

  if (tagType !== null) {
    requireSupportedTagType_(tagType);
  }
  if (normalizedName === null && tagName !== null) {
    normalizedName = normalizeTagName_(tagName);
  }

  return {
    rowNumber: rowNumber,
    values: row,
    tagId: optionalSheetString_(row[0]),
    tagType: tagType,
    normalizedName: normalizedName
  };
}

/**
 * 初期タグ定義を検証・正規化する。
 *
 * @param {Object} seed
 * @return {Object}
 */
function normalizeTagSeed_(seed) {
  var tagId = getOptionalString(seed.tagId);
  var tagType = getOptionalString(seed.tagType);
  var tagName = getOptionalString(seed.tagName);
  var displayOrder = Number(seed.displayOrder);

  if (tagId === null || tagType === null || tagName === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      '初期タグ定義に必須項目がありません。'
    );
  }

  requireSupportedTagType_(tagType);

  if (!isFinite(displayOrder)) {
    throw createApiError_(
      'INTERNAL_ERROR',
      '初期タグのdisplayOrderが数値ではありません。'
    );
  }

  return {
    tagId: tagId,
    tagType: tagType,
    tagName: tagName,
    normalizedName: normalizeTagName_(tagName),
    displayOrder: displayOrder
  };
}

/**
 * 初期タグをTagsシートの1行へ変換する。
 *
 * @param {Object} seed
 * @param {string} tagId
 * @param {*} createdAt
 * @param {*} updatedAt
 * @return {Array<*>}
 */
function tagSeedRow_(seed, tagId, createdAt, updatedAt) {
  return [
    tagId,
    seed.tagType,
    seed.tagName,
    seed.normalizedName,
    seed.displayOrder,
    true,
    createdAt,
    updatedAt
  ];
}

/**
 * updatedAtを除き、既存行が初期タグ定義と一致するか確認する。
 *
 * @param {Array<*>} existingRow
 * @param {Array<*>} desiredRow
 * @return {boolean}
 */
function tagSeedRowMatches_(existingRow, desiredRow) {
  return String(existingRow[0]).trim() === String(desiredRow[0]).trim()
    && String(existingRow[1]).trim() === String(desiredRow[1]).trim()
    && String(existingRow[2]).trim() === String(desiredRow[2]).trim()
    && String(existingRow[3]).trim() === String(desiredRow[3]).trim()
    && Number(existingRow[4]) === Number(desiredRow[4])
    && sheetBoolean_(existingRow[5]) === true
    && !isBlankSheetCell_(existingRow[6]);
}

/**
 * タグ名を重複判定用に正規化する。
 *
 * @param {*} value
 * @return {string}
 */
function normalizeTagName_(value) {
  return String(value)
    .normalize('NFKC')
    .trim()
    .toLowerCase()
    .replace(/[\s\u3000]+/g, '');
}

/**
 * タグ種類と正規化名から一意キーを作る。
 *
 * @param {string} tagType
 * @param {string} normalizedName
 * @return {string}
 */
function tagNormalizedKey_(tagType, normalizedName) {
  return tagType + '\u0000' + normalizedName;
}

/**
 * 対応するタグ種類か確認する。
 *
 * @param {string} tagType
 */
function requireSupportedTagType_(tagType) {
  if (supportedTagTypeIndex_(tagType) < 0) {
    throw createApiError_(
      'VALIDATION_ERROR',
      '未対応のtagTypeです: ' + tagType
    );
  }
}

/**
 * タグ種類の表示順を返す。
 *
 * @param {string} tagType
 * @return {number}
 */
function supportedTagTypeIndex_(tagType) {
  return SUPPORTED_TAG_TYPES.indexOf(tagType);
}

/**
 * 初期タグ投入を2回実行し、重複しないことを確認する。
 */
function testSeedInitialTags() {
  var firstResult = seedInitialTags();
  var secondResult = seedInitialTags();
  var spreadsheet = getDataSpreadsheet_();
  var activeTags = readSheetObjects_(spreadsheet, 'Tags')
    .map(normalizeTagRow_)
    .filter(function(tag) {
      return tag.isActive;
    });

  var uniqueKeys = {};
  activeTags.forEach(function(tag) {
    var key = tagNormalizedKey_(tag.tagType, tag.normalizedName);
    if (uniqueKeys[key]) {
      throw createApiError_(
        'DUPLICATE',
        '同じ種類・名前のタグが重複しています。'
      );
    }
    uniqueKeys[key] = true;
  });

  console.log('1回目: ' + JSON.stringify(firstResult));
  console.log('2回目: ' + JSON.stringify(secondResult));
  console.log('有効タグ件数: ' + activeTags.length);
}
