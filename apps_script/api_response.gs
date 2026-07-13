/**
 * API共通形式のJSON応答を作成する。
 *
 * @param {boolean} ok
 * @param {string|null} requestId
 * @param {Object|null} data
 * @param {string|null} errorCode
 * @param {string|null} message
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function createApiResponse(
  ok,
  requestId,
  data,
  errorCode,
  message
) {
  var response = {
    ok: ok,
    requestId: requestId,
    serverTime: getJapanIsoDateTime(),
    data: data,
    errorCode: errorCode,
    message: message
  };

  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * 日本時間をISO 8601形式で返す。
 *
 * @return {string}
 */
function getJapanIsoDateTime() {
  return Utilities.formatDate(
    new Date(),
    'Asia/Tokyo',
    "yyyy-MM-dd'T'HH:mm:ss"
  ) + '+09:00';
}
