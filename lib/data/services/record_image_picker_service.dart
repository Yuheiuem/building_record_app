import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../models/record_draft_photo.dart';

abstract interface class RecordImagePickerService {
  Future<List<RecordDraftPhoto>> pickImages();
}

class ImagePickerRecordImageService implements RecordImagePickerService {
  ImagePickerRecordImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async {
    final List<XFile> files = await _picker.pickMultiImage(
      maxWidth: AppConfig.recordImageMaxDimension.toDouble(),
      maxHeight: AppConfig.recordImageMaxDimension.toDouble(),
      imageQuality: AppConfig.recordImageQuality,
      requestFullMetadata: false,
    );

    final List<RecordDraftPhoto> photos = <RecordDraftPhoto>[];

    for (final XFile file in files) {
      photos.add(
        RecordDraftPhoto(
          photoId: const Uuid().v4(),
          fileName: file.name,
          mimeType: _normalizeMimeType(
            file.mimeType ?? _inferMimeType(file.name),
          ),
          bytes: await file.readAsBytes(),
        ),
      );
    }

    return photos;
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
