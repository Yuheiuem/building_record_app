import 'package:flutter/foundation.dart';

@immutable
class RecordDraftPhoto {
  const RecordDraftPhoto({
    required this.photoId,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String photoId;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get byteSize => bytes.length;

  bool get isSupportedImage =>
      mimeType == 'image/jpeg' || mimeType == 'image/png';
}
