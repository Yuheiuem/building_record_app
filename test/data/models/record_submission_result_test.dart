import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('写真送信の詳細な計測値を読み取れる', () {
    final UploadRecordPhotoResult result = UploadRecordPhotoResult.fromJson(
      <String, dynamic>{
        'photoId': 'photo-12345678',
        'storageFileId': 'file-12345678',
        'byteSize': 1234,
        'displayOrder': 1,
        'reused': false,
        'performance': <String, dynamic>{
          'authenticationMode': 'cache',
          'authenticationMs': 10,
          'lockWaitMs': 20,
          'spreadsheetOpenMs': 30,
          'responseCacheMs': 40,
          'lookupMs': 50,
          'base64DecodeMs': 60,
          'thumbnailBase64DecodeMs': 70,
          'driveSaveMs': 80,
          'thumbnailDriveSaveMs': 90,
          'sheetWriteMs': 100,
          'draftPreparationMs': 110,
          'finalizeMs': 120,
          'handlerTotalMs': 130,
        },
      },
      clientEncodeMs: 140,
      clientRequestMs: 150,
      clientOriginalBase64Ms: 160,
      clientThumbnailCreateMs: 170,
      clientThumbnailBase64Ms: 180,
    );

    final RecordUploadPerformance performance = result.performance!;
    expect(performance.clientEncodeMs, 140);
    expect(performance.clientRequestMs, 150);
    expect(performance.clientOriginalBase64Ms, 160);
    expect(performance.clientThumbnailCreateMs, 170);
    expect(performance.clientThumbnailBase64Ms, 180);
    expect(performance.authenticationMode, 'cache');
    expect(performance.authenticationMs, 10);
    expect(performance.lockWaitMs, 20);
    expect(performance.spreadsheetOpenMs, 30);
    expect(performance.responseCacheMs, 40);
    expect(performance.lookupMs, 50);
    expect(performance.base64DecodeMs, 60);
    expect(performance.thumbnailBase64DecodeMs, 70);
    expect(performance.driveSaveMs, 80);
    expect(performance.thumbnailDriveSaveMs, 90);
    expect(performance.sheetWriteMs, 100);
    expect(performance.draftPreparationMs, 110);
    expect(performance.finalizeMs, 120);
    expect(performance.handlerTotalMs, 130);
  });

  test('準備通信と確定通信の詳細な計測値を読み取れる', () {
    final BeginRecordResult begin = BeginRecordResult.fromJson(
      <String, dynamic>{
        'buildingId': 'building-12345678',
        'visitId': 'visit-12345678',
        'expectedPhotoCount': 2,
        'buildingCreated': true,
        'visitCreated': true,
        'reused': false,
        'performance': <String, dynamic>{
          'authenticationMode': 'cache',
          'authenticationMs': 10,
          'normalizeMs': 20,
          'spreadsheetOpenMs': 30,
          'lockWaitMs': 40,
          'requestLookupMs': 50,
          'tagValidationMs': 60,
          'buildingEnsureMs': 70,
          'visitEnsureMs': 80,
          'uploadContextCacheMs': 90,
          'requestLogWriteMs': 100,
          'handlerTotalMs': 110,
          'unclassifiedMs': 120,
        },
      },
    );

    expect(begin.performance?.authenticationMode, 'cache');
    expect(begin.performance?.authenticationMs, 10);
    expect(begin.performance?.normalizeMs, 20);
    expect(begin.performance?.spreadsheetOpenMs, 30);
    expect(begin.performance?.lockWaitMs, 40);
    expect(begin.performance?.requestLookupMs, 50);
    expect(begin.performance?.tagValidationMs, 60);
    expect(begin.performance?.buildingEnsureMs, 70);
    expect(begin.performance?.visitEnsureMs, 80);
    expect(begin.performance?.uploadContextCacheMs, 90);
    expect(begin.performance?.requestLogWriteMs, 100);
    expect(begin.performance?.handlerTotalMs, 110);
    expect(begin.performance?.unclassifiedMs, 120);

    final FinalizeRecordResult finalize = FinalizeRecordResult.fromJson(
      <String, dynamic>{
        'buildingId': 'building-12345678',
        'visitId': 'visit-12345678',
        'photoCount': 2,
        'status': 'completed',
        'reused': false,
        'performance': <String, dynamic>{
          'authenticationMode': 'tokeninfo',
          'authenticationMs': 11,
          'normalizeMs': 21,
          'spreadsheetOpenMs': 31,
          'lockWaitMs': 41,
          'requestLookupMs': 51,
          'buildingLookupMs': 61,
          'visitLookupMs': 71,
          'photosLookupMs': 81,
          'visitUpdateMs': 91,
          'buildingUpdateMs': 101,
          'requestLogWriteMs': 111,
          'handlerTotalMs': 121,
          'unclassifiedMs': 131,
        },
      },
    );

    expect(finalize.performance?.authenticationMode, 'tokeninfo');
    expect(finalize.performance?.authenticationMs, 11);
    expect(finalize.performance?.normalizeMs, 21);
    expect(finalize.performance?.spreadsheetOpenMs, 31);
    expect(finalize.performance?.lockWaitMs, 41);
    expect(finalize.performance?.requestLookupMs, 51);
    expect(finalize.performance?.buildingLookupMs, 61);
    expect(finalize.performance?.visitLookupMs, 71);
    expect(finalize.performance?.photosLookupMs, 81);
    expect(finalize.performance?.visitUpdateMs, 91);
    expect(finalize.performance?.buildingUpdateMs, 101);
    expect(finalize.performance?.requestLogWriteMs, 111);
    expect(finalize.performance?.handlerTotalMs, 121);
    expect(finalize.performance?.unclassifiedMs, 131);
  });
}
