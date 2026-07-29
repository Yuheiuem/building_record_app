var TOKENINFO_ENDPOINT = 'https://oauth2.googleapis.com/tokeninfo';
var AUTH_CACHE_PREFIX = 'verified-id-token:';
var AUTH_CACHE_MAX_SECONDS = 300;
var AUTH_CACHE_EXPIRY_SAFETY_SECONDS = 30;

/**
 * API要求に含まれるGoogle IDトークンを検証する。
 *
 * 同じIDトークンを短時間に繰り返し検証する場合は、
 * tokeninfoの検証結果をScript Cacheから再利用する。
 * キャッシュキーにはトークン本文ではなくSHA-256ハッシュを使う。
 *
 * @param {Object} request
 * @return {{
 *   subject: string,
 *   email: string,
 *   verificationMode: string,
 *   verificationMs: number
 * }}
 */
function verifyRequestAuthentication(request) {
  var startedAt = Date.now();
  var idToken = getOptionalString(request.idToken);
  if (idToken === null) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'Googleログインが必要です。'
    );
  }

  var properties = PropertiesService.getScriptProperties();
  var expectedClientId = getRequiredScriptProperty_(
    properties,
    'GOOGLE_OAUTH_CLIENT_ID'
  );
  var allowedEmail = getRequiredScriptProperty_(
    properties,
    'ALLOWED_EMAIL'
  ).toLowerCase();

  var cachedContext = getCachedAuthentication_(
    idToken,
    expectedClientId,
    allowedEmail,
    properties
  );
  if (cachedContext !== null) {
    cachedContext.verificationMode = 'cache';
    cachedContext.verificationMs = Date.now() - startedAt;
    return cachedContext;
  }

  var tokenInfo = fetchGoogleTokenInfo_(idToken);
  validateTokenClaims_(tokenInfo, expectedClientId, allowedEmail);
  registerOrValidateAllowedSubject_(properties, tokenInfo.sub);
  cacheVerifiedAuthentication_(idToken, tokenInfo, expectedClientId);

  return {
    subject: tokenInfo.sub,
    email: tokenInfo.email,
    verificationMode: 'tokeninfo',
    verificationMs: Date.now() - startedAt
  };
}

/**
 * Google tokeninfoへIDトークンを送り、検証済みクレームを取得する。
 * トークン本文はログへ出力しない。
 *
 * @param {string} idToken
 * @return {Object}
 */
function fetchGoogleTokenInfo_(idToken) {
  var response = UrlFetchApp.fetch(
    TOKENINFO_ENDPOINT + '?id_token=' + encodeURIComponent(idToken),
    {
      method: 'get',
      muteHttpExceptions: true,
      followRedirects: true
    }
  );

  if (response.getResponseCode() !== 200) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'IDトークンが無効または期限切れです。もう一度ログインしてください。'
    );
  }

  try {
    return JSON.parse(response.getContentText('UTF-8'));
  } catch (error) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'IDトークンの検証結果を読み取れませんでした。'
    );
  }
}

/**
 * tokeninfoが返したクレームをアプリ設定と照合する。
 *
 * @param {Object} tokenInfo
 * @param {string} expectedClientId
 * @param {string} allowedEmail
 */
function validateTokenClaims_(
  tokenInfo,
  expectedClientId,
  allowedEmail
) {
  var issuer = getOptionalString(tokenInfo.iss);
  var audience = getOptionalString(tokenInfo.aud);
  var email = getOptionalString(tokenInfo.email);
  var subject = getOptionalString(tokenInfo.sub);
  var expiry = Number(tokenInfo.exp);
  var emailVerified = tokenInfo.email_verified === true ||
    tokenInfo.email_verified === 'true';

  if (
    issuer !== 'accounts.google.com' &&
    issuer !== 'https://accounts.google.com'
  ) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'IDトークンの発行元を確認できませんでした。'
    );
  }

  if (audience !== expectedClientId) {
    throw createApiError_(
      'FORBIDDEN',
      'このアプリ向けのIDトークンではありません。'
    );
  }

  if (!Number.isFinite(expiry) || expiry <= Math.floor(Date.now() / 1000)) {
    throw createApiError_(
      'AUTH_REQUIRED',
      'IDトークンの有効期限が切れています。もう一度ログインしてください。'
    );
  }

  if (!emailVerified || email === null || subject === null) {
    throw createApiError_(
      'FORBIDDEN',
      'Googleアカウントを確認できませんでした。'
    );
  }

  if (email.toLowerCase() !== allowedEmail) {
    throw createApiError_(
      'FORBIDDEN',
      'このGoogleアカウントにはアクセス権限がありません。'
    );
  }
}

/**
 * 検証済みIDトークンのキャッシュを取得する。
 * Script Propertiesの現在値とも照合し、設定変更後の誤利用を防ぐ。
 *
 * @param {string} idToken
 * @param {string} expectedClientId
 * @param {string} allowedEmail
 * @param {GoogleAppsScript.Properties.Properties} properties
 * @return {{subject: string, email: string}|null}
 */
function getCachedAuthentication_(
  idToken,
  expectedClientId,
  allowedEmail,
  properties
) {
  var cache = CacheService.getScriptCache();
  var cacheKey = buildAuthenticationCacheKey_(idToken);
  var cachedText = cache.get(cacheKey);
  if (cachedText === null) {
    return null;
  }

  var cached;
  try {
    cached = JSON.parse(cachedText);
  } catch (error) {
    cache.remove(cacheKey);
    return null;
  }

  var subject = getOptionalString(cached.subject);
  var email = getOptionalString(cached.email);
  var clientId = getOptionalString(cached.clientId);
  var expiry = Number(cached.expiry);
  var nowSeconds = Math.floor(Date.now() / 1000);
  var allowedSubject = getOptionalString(
    properties.getProperty('ALLOWED_SUB')
  );

  if (
    subject === null ||
    email === null ||
    clientId !== expectedClientId ||
    email.toLowerCase() !== allowedEmail ||
    !Number.isFinite(expiry) ||
    expiry <= nowSeconds + AUTH_CACHE_EXPIRY_SAFETY_SECONDS ||
    allowedSubject === null ||
    allowedSubject !== subject
  ) {
    cache.remove(cacheKey);
    return null;
  }

  return {
    subject: subject,
    email: email
  };
}

/**
 * 検証済みIDトークンを最大5分間キャッシュする。
 * IDトークンの残り有効時間が短い場合は、それより前に失効させる。
 *
 * @param {string} idToken
 * @param {Object} tokenInfo
 * @param {string} expectedClientId
 */
function cacheVerifiedAuthentication_(
  idToken,
  tokenInfo,
  expectedClientId
) {
  var expiry = Number(tokenInfo.exp);
  var nowSeconds = Math.floor(Date.now() / 1000);
  var remainingSeconds = Math.floor(
    expiry - nowSeconds - AUTH_CACHE_EXPIRY_SAFETY_SECONDS
  );
  var cacheSeconds = Math.min(
    AUTH_CACHE_MAX_SECONDS,
    remainingSeconds
  );

  if (!Number.isFinite(cacheSeconds) || cacheSeconds <= 0) {
    return;
  }

  CacheService.getScriptCache().put(
    buildAuthenticationCacheKey_(idToken),
    JSON.stringify({
      subject: tokenInfo.sub,
      email: tokenInfo.email,
      clientId: expectedClientId,
      expiry: expiry
    }),
    cacheSeconds
  );
}

/**
 * IDトークン本文を保持しないキャッシュキーを作る。
 *
 * @param {string} idToken
 * @return {string}
 */
function buildAuthenticationCacheKey_(idToken) {
  var digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    idToken,
    Utilities.Charset.UTF_8
  );
  var encoded = Utilities.base64EncodeWebSafe(digest)
    .replace(/=+$/g, '');
  return AUTH_CACHE_PREFIX + encoded;
}

/**
 * 初回成功時にGoogleアカウント固有のsubをScript Propertiesへ登録し、
 * 2回目以降は同じsubであることを確認する。
 *
 * @param {GoogleAppsScript.Properties.Properties} properties
 * @param {string} subject
 */
function registerOrValidateAllowedSubject_(properties, subject) {
  var lock = LockService.getScriptLock();
  lock.waitLock(5000);

  try {
    var allowedSubject = getOptionalString(
      properties.getProperty('ALLOWED_SUB')
    );

    if (allowedSubject === null) {
      properties.setProperty('ALLOWED_SUB', subject);
      return;
    }

    if (allowedSubject !== subject) {
      throw createApiError_(
        'FORBIDDEN',
        '登録済みのGoogleアカウントと一致しません。'
      );
    }
  } finally {
    lock.releaseLock();
  }
}

/**
 * 必須のScript Propertyを取得する。
 *
 * @param {GoogleAppsScript.Properties.Properties} properties
 * @param {string} key
 * @return {string}
 */
function getRequiredScriptProperty_(properties, key) {
  var value = getOptionalString(properties.getProperty(key));

  if (value === null) {
    throw createApiError_(
      'INTERNAL_ERROR',
      'Apps Scriptの認証設定が不足しています。'
    );
  }

  return value;
}

/**
 * APIエラー情報を持つErrorを作成する。
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
 * UrlFetchAppの権限確認用。Apps Scriptエディタから1回だけ実行する。
 */
function testExternalRequestAuthorization() {
  var response = UrlFetchApp.fetch(
    'https://accounts.google.com/.well-known/openid-configuration',
    {
      method: 'get',
      muteHttpExceptions: true
    }
  );

  console.log('HTTP ' + response.getResponseCode());
}
