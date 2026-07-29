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
    final UploadRecordPhotoResult result =
        UploadRecordPhotoResult.fromJson(<String, dynamic>{
          'photoId': 'photo-1',
          'storageFileId': 'drive-file-1',
          'byteSize': 1234,
          'displayOrder': 1,
          'reused': true,
        });

    expect(result.photoId, 'photo-1');
    expect(result.storageFileId, 'drive-file-1');
    expect(result.reused, isTrue);
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
