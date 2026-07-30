import 'package:building_record_app/data/models/record_submission_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beginRecord応答を変換できる', () {
    final BeginRecordResult result =
        BeginRecordResult.fromJson(<String, dynamic>{
          'buildingId': 'building-1',
          'visitId': 'visit-1',
          'expectedPhotoCount': 2,
          'buildingCreated': true,
          'visitCreated': true,
          'reused': false,
        });

    expect(result.buildingId, 'building-1');
    expect(result.visitId, 'visit-1');
    expect(result.expectedPhotoCount, 2);
    expect(result.buildingCreated, isTrue);
  });

  test('uploadPhoto応答を変換できる', () {
    final UploadRecordPhotoResult result = UploadRecordPhotoResult.fromJson(
      <String, dynamic>{
        'photoId': 'photo-1',
        'storageFileId': 'drive-file-1',
        'byteSize': 1234,
        'displayOrder': 1,
        'reused': true,
        'buildingId': 'building-1',
        'visitId': 'visit-1',
        'recordPrepared': true,
        'buildingCreated': true,
        'visitCreated': true,
        'recordCompleted': true,
        'photoCount': 1,
        'saveMode': 'combined_photo_step',
        'performance': <String, dynamic>{
          'authenticationMode': 'cache',
          'authenticationMs': 4,
          'lockWaitMs': 1,
          'lookupMs': 12,
          'base64DecodeMs': 8,
          'driveSaveMs': 420,
          'sheetWriteMs': 55,
          'draftPreparationMs': 120,
          'finalizeMs': 80,
          'handlerTotalMs': 510,
        },
      },
      clientEncodeMs: 6,
      clientRequestMs: 640,
    );

    expect(result.photoId, 'photo-1');
    expect(result.storageFileId, 'drive-file-1');
    expect(result.reused, isTrue);
    expect(result.performance?.authenticationMode, 'cache');
    expect(result.buildingId, 'building-1');
    expect(result.recordPrepared, isTrue);
    expect(result.recordCompleted, isTrue);
    expect(result.photoCount, 1);
    expect(result.saveMode, 'combined_photo_step');
    expect(result.performance?.driveSaveMs, 420);
    expect(result.performance?.draftPreparationMs, 120);
    expect(result.performance?.finalizeMs, 80);
    expect(result.performance?.clientTotalDuration.inMilliseconds, 646);
  });

  test('finalizeRecord応答を変換できる', () {
    final FinalizeRecordResult result =
        FinalizeRecordResult.fromJson(<String, dynamic>{
          'buildingId': 'building-1',
          'visitId': 'visit-1',
          'photoCount': 2,
          'status': 'completed',
          'reused': false,
        });

    expect(result.photoCount, 2);
    expect(result.status, 'completed');
  });
}
