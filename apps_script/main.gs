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
    var authContext = verifyRequestAuthentication(request);
    switch (request.action) {
      case 'healthCheck':
        return handleHealthCheck(requestId, authContext);
      case 'uploadSpikePhoto':
        return handleUploadSpikePhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'getSpikePhoto':
        return handleGetSpikePhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'getBootstrapData':
        return handleGetBootstrapData(
          requestId,
          request.payload,
          authContext
        );
      case 'getBuildingDetail':
        return handleGetBuildingDetail(
          requestId,
          request.payload,
          authContext
        );
      case 'getPhotoData':
        return handleGetPhotoData(
          requestId,
          request.payload,
          authContext
        );
      case 'getPhotoThumbnailData':
        return handleGetPhotoThumbnailData(
          requestId,
          request.payload,
          authContext
        );
      case 'getHiddenBuildingPhotos':
        return handleGetHiddenBuildingPhotos(
          requestId,
          request.payload,
          authContext
        );
      case 'getHiddenPhotoThumbnailData':
        return handleGetHiddenPhotoThumbnailData(
          requestId,
          request.payload,
          authContext
        );
      case 'hidePhoto':
        return handleHidePhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'restorePhoto':
        return handleRestorePhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'deletePhotoPermanently':
        return handleDeletePhotoPermanently(
          requestId,
          request.payload,
          authContext
        );
      case 'getHiddenBuildings':
        return handleGetHiddenBuildings(
          requestId,
          request.payload,
          authContext
        );
      case 'getBuildingDeletionPreview':
        return handleGetBuildingDeletionPreview(
          requestId,
          request.payload,
          authContext
        );
      case 'hideBuilding':
        return handleHideBuilding(
          requestId,
          request.payload,
          authContext
        );
      case 'restoreBuilding':
        return handleRestoreBuilding(
          requestId,
          request.payload,
          authContext
        );
      case 'deleteBuildingPermanently':
        return handleDeleteBuildingPermanently(
          requestId,
          request.payload,
          authContext
        );
      case 'getHiddenBuildingVisits':
        return handleGetHiddenBuildingVisits(
          requestId,
          request.payload,
          authContext
        );
      case 'hideVisit':
        return handleHideVisit(
          requestId,
          request.payload,
          authContext
        );
      case 'restoreVisit':
        return handleRestoreVisit(
          requestId,
          request.payload,
          authContext
        );
      case 'deleteVisitPermanently':
        return handleDeleteVisitPermanently(
          requestId,
          request.payload,
          authContext
        );
      case 'getCoverPhotoThumbnails':
        return handleGetCoverPhotoThumbnails(
          requestId,
          request.payload,
          authContext
        );
      case 'updateBuildingLocation':
        return handleUpdateBuildingLocation(
          requestId,
          request.payload,
          authContext
        );
      case 'updateBuildingInformation':
        return handleUpdateBuildingInformation(
          requestId,
          request.payload,
          authContext
        );
      case 'updateBuildingCoverPhoto':
        return handleUpdateBuildingCoverPhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'updateVisitInformation':
        return handleUpdateVisitInformation(
          requestId,
          request.payload,
          authContext
        );
      case 'createTag':
        return handleCreateTag(
          requestId,
          request.payload,
          authContext
        );
      case 'beginRecord':
        return handleBeginRecord(
          requestId,
          request.payload,
          authContext
        );
      case 'uploadPhoto':
        return handleUploadPhoto(
          requestId,
          request.payload,
          authContext
        );
      case 'uploadPhotosBatch':
        return handleUploadPhotosBatch(
          requestId,
          request.payload,
          authContext
        );
      case 'uploadPhotoThumbnail':
        return handleUploadPhotoThumbnail(
          requestId,
          request.payload,
          authContext
        );
      case 'finalizeRecord':
        return handleFinalizeRecord(
          requestId,
          request.payload,
          authContext
        );
      default:
        throw createApiError_(
          'VALIDATION_ERROR',
          '未対応のactionです。'
        );
    }
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
  requireAuthenticatedContext_(authContext);
  return createApiResponse(
    true,
    requestId,
    {
      status: 'ok',
      stage: '5-5.4',
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
 * 値が文字列なら空白を除いて返し、それ以外はnullを返す。
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
 * 認証済みコンテキストを要求する。
 *
 * @param {{subject: string, email: string}|null} authContext
 */
function requireAuthenticatedContext_(authContext) {
  if (!authContext || !authContext.subject) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'Googleアカウントを確認できませんでした。'
    );
  }
}

/**
 * API用のエラーを作成する。
 *
 * @param {string} errorCode
 * @param {string} message
 * @return {Error}
 */
function createApiError_(errorCode, message) {
  var error = new Error(message);
  error.apiErrorCode = errorCode;
  return error;
}

/**
 * IDトークンなしのhealthCheckが拒否されることを確認する。
 */
function testUnauthenticatedHealthCheck() {
  var event = {
    postData: {
      contents: JSON.stringify({
        action: 'healthCheck',
        requestId: 'apps-script-editor-test',
        idToken: null,
        clientVersion: 'v0.19.9',
        payload: {}
      })
    }
  };

  var response = doPost(event);
  console.log(response.getContent());
}
