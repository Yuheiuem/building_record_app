import 'dart:typed_data';

import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('複数写真を下書きへ追加し合計容量を計算する', () async {
    final _FakeRecordImagePickerService picker =
        _FakeRecordImagePickerService(<RecordDraftPhoto>[
          _photo(id: 'photo-1', fileName: 'one.jpg', byteSize: 1200),
          _photo(id: 'photo-2', fileName: 'two.png', byteSize: 2400),
        ]);
    final RecordDraftController controller = RecordDraftController(
      imagePickerService: picker,
    );

    await controller.addPhotos();

    expect(controller.photoCount, 2);
    expect(controller.totalBytes, 3600);
    expect(controller.noticeMessage, '2枚を下書きへ追加しました。');
    expect(controller.errorMessage, isNull);
  });

  test('個別写真を削除できる', () async {
    final RecordDraftController controller = RecordDraftController(
      imagePickerService: _FakeRecordImagePickerService(<RecordDraftPhoto>[
        _photo(id: 'photo-1', fileName: 'one.jpg', byteSize: 1200),
        _photo(id: 'photo-2', fileName: 'two.png', byteSize: 2400),
      ]),
    );

    await controller.addPhotos();
    controller.removePhoto('photo-1');

    expect(controller.photoCount, 1);
    expect(controller.photos.single.photoId, 'photo-2');
    expect(controller.totalBytes, 2400);
  });

  test('未対応形式と5MB超過写真は追加しない', () async {
    final RecordDraftController controller = RecordDraftController(
      imagePickerService: _FakeRecordImagePickerService(<RecordDraftPhoto>[
        RecordDraftPhoto(
          photoId: 'unsupported',
          fileName: 'photo.heic',
          mimeType: 'image/heic',
          bytes: Uint8List(100),
        ),
        _photo(
          id: 'oversized',
          fileName: 'large.jpg',
          byteSize: 5 * 1024 * 1024 + 1,
        ),
        _photo(id: 'accepted', fileName: 'ok.jpg', byteSize: 1000),
      ]),
    );

    await controller.addPhotos();

    expect(controller.photoCount, 1);
    expect(controller.photos.single.photoId, 'accepted');
    expect(controller.errorMessage, '未対応形式 1枚、5MB超過 1枚は追加しませんでした。');
  });
}

RecordDraftPhoto _photo({
  required String id,
  required String fileName,
  required int byteSize,
}) {
  return RecordDraftPhoto(
    photoId: id,
    fileName: fileName,
    mimeType: fileName.endsWith('.png') ? 'image/png' : 'image/jpeg',
    bytes: Uint8List(byteSize),
  );
}

class _FakeRecordImagePickerService implements RecordImagePickerService {
  _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
}
