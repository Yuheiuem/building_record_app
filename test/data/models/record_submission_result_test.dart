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
}
