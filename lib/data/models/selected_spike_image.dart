import 'package:flutter/foundation.dart';

@immutable
class SelectedSpikeImage {
  const SelectedSpikeImage({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get byteSize => bytes.length;
}
