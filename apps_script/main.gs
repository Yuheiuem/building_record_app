/**
 * URLを直接開いた場合は、認証が必要であることだけを返す。
 *
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function doGet() {
  return createApiResponse(
    false,
    null,
    null,
    'AUTH_REQUIRED',
    'POSTリクエストでGoogle IDトークンを送信してください。'
  );
}

/**
 * FlutterなどのクライアントからPOSTされたAPI要求を処理する。
 *
 * @param {Object} e Apps ScriptのPOSTイベント
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function doPost(e) {
  var requestId = null;

  try {
    var request = parseJsonRequest(e);
    requestId = getOptionalString(request.requestId);

    if (request.action !== 'healthCheck') {
      throw createApiError_(
        'VALIDATION_ERROR',
        '未対応のactionです。'
      );
    }

    var authContext = verifyRequestAuthentication(request);
    return handleHealthCheck(requestId, authContext);
  } catch (error) {
    var errorCode = error && error.apiErrorCode
      ? error.apiErrorCode
      : 'INTERNAL_ERROR';
    var message = error && typeof error.message === 'string'
      ? error.message
      : 'リクエストを処理できませんでした。';

    return createApiResponse(
      false,
      requestId,
      null,
      errorCode,
      message
    );
  }
}

/**
 * 認証済みhealthCheck要求を処理する。
 *
 * @param {string|null} requestId
 * @param {{subject: string, email: string}} authContext
 * @return {GoogleAppsScript.Content.TextOutput}
 */
function handleHealthCheck(requestId, authContext) {
  if (!authContext || !authContext.subject) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'Googleアカウントを確認できませんでした。'
    );
  }

  return createApiResponse(
    true,
    requestId,
    {
      status: 'ok',
      stage: '0-3D',
      method: 'POST',
      authenticated: true,
      validationMode: 'tokeninfo_spike'
    },
    null,
    null
  );
}

/**
 * POST本文をJSONとして読み込む。
 *
 * @param {Object} e
 * @return {Object}
 */
function parseJsonRequest(e) {
  if (
    !e ||
    !e.postData ||
    typeof e.postData.contents !== 'string' ||
    e.postData.contents.trim() === ''
  ) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'POST本文がありません。'
    );
  }

  var parsed;
  try {
    parsed = JSON.parse(e.postData.contents);
  } catch (error) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'POST本文が正しいJSONではありません。'
    );
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw createApiError_(
      'VALIDATION_ERROR',
      'JSONオブジェクトではありません。'
    );
  }

  return parsed;
}

/**
 * 値が文字列なら返し、それ以外はnullを返す。
 *
 * @param {*} value
 * @return {string|null}
 */
function getOptionalString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  var trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

/**
 * Apps Scriptエディタから未認証要求の拒否を確認する。
 */
function testUnauthenticatedHealthCheck() {
  var event = {
    postData: {
      contents: JSON.stringify({
        action: 'healthCheck',
        requestId: 'apps-script-editor-test',
        idToken: null,
        clientVersion: 'v0.4.0',
        payload: {}
      })
    }
  };

  var response = doPost(event);
  console.log(response.getContent());
}
