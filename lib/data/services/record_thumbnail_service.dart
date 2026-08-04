import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../../core/config/app_config.dart';

class RecordThumbnailData {
  const RecordThumbnailData({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;

  int get byteSize => bytes.length;
}

abstract interface class RecordThumbnailService {
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes);
}

class ImageRecordThumbnailService implements RecordThumbnailService {
  const ImageRecordThumbnailService();

  @override
  Future<RecordThumbnailData?> createThumbnail(Uint8List sourceBytes) async {
    try {
      final image.Image? decoded = image.decodeImage(sourceBytes);
      if (decoded == null) {
        return null;
      }

      final image.Image oriented = image.bakeOrientation(decoded);
      final image.Image resized = _resize(oriented);
      final Uint8List encoded = _encodeWithinLimit(resized);

      return RecordThumbnailData(
        bytes: encoded,
        mimeType: 'image/jpeg',
        width: resized.width,
        height: resized.height,
      );
    } catch (_) {
      // サムネイル生成だけに失敗しても、元写真の保存は継続する。
      return null;
    }
  }

  image.Image _resize(image.Image source) {
    final int longestSide = source.width >= source.height
        ? source.width
        : source.height;
    if (longestSide <= AppConfig.recordThumbnailMaxDimension) {
      return source;
    }

    if (source.width >= source.height) {
      return image.copyResize(
        source,
        width: AppConfig.recordThumbnailMaxDimension,
        interpolation: image.Interpolation.average,
      );
    }
    return image.copyResize(
      source,
      height: AppConfig.recordThumbnailMaxDimension,
      interpolation: image.Interpolation.average,
    );
  }

  Uint8List _encodeWithinLimit(image.Image source) {
    int quality = AppConfig.recordThumbnailQuality;
    Uint8List encoded = Uint8List.fromList(
      image.encodeJpg(source, quality: quality),
    );

    while (encoded.length > AppConfig.recordThumbnailMaxBytes &&
        quality > AppConfig.recordThumbnailMinQuality) {
      quality -= 7;
      if (quality < AppConfig.recordThumbnailMinQuality) {
        quality = AppConfig.recordThumbnailMinQuality;
      }
      encoded = Uint8List.fromList(image.encodeJpg(source, quality: quality));
    }

    return encoded;
  }
}
