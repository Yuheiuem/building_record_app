import 'package:image_picker/image_picker.dart';

import '../models/selected_spike_image.dart';

abstract interface class SpikeImagePickerService {
  Future<SelectedSpikeImage?> pickSingleImage();
}

class ImagePickerSpikeService implements SpikeImagePickerService {
  ImagePickerSpikeService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<SelectedSpikeImage?> pickSingleImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      requestFullMetadata: false,
    );

    if (file == null) {
      return null;
    }

    final String mimeType = _normalizeMimeType(
      file.mimeType ?? _inferMimeType(file.name),
    );

    return SelectedSpikeImage(
      fileName: file.name,
      mimeType: mimeType,
      bytes: await file.readAsBytes(),
    );
  }

  String _normalizeMimeType(String? mimeType) {
    if (mimeType == 'image/jpg') {
      return 'image/jpeg';
    }
    return mimeType ?? 'application/octet-stream';
  }

  String? _inferMimeType(String fileName) {
    final String lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    return null;
  }
}
