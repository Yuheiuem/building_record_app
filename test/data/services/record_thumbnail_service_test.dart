import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/services/record_thumbnail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  const ImageRecordThumbnailService service = ImageRecordThumbnailService();

  test('長辺480pxのJPEGサムネイルを作成する', () async {
    final image.Image source = image.Image(width: 960, height: 480);
    final Uint8List sourceBytes = Uint8List.fromList(image.encodePng(source));

    final RecordThumbnailData? result = await service.createThumbnail(
      sourceBytes,
    );

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/jpeg');
    expect(result.width, AppConfig.recordThumbnailMaxDimension);
    expect(result.height, 240);
    expect(
      result.byteSize,
      lessThanOrEqualTo(AppConfig.recordThumbnailMaxBytes),
    );

    final image.Image? decoded = image.decodeImage(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, AppConfig.recordThumbnailMaxDimension);
    expect(decoded.height, 240);
  });

  test('画像として読み取れないデータではnullを返す', () async {
    final RecordThumbnailData? result = await service.createThumbnail(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
    );

    expect(result, isNull);
  });
}
