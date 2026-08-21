import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../models/record_draft_photo.dart';

enum RecordImagePickProgressPhase { selectingAndConverting, readingFiles }

class RecordImagePickProgress {
  const RecordImagePickProgress({
    required this.phase,
    this.current = 0,
    this.total = 0,
    this.fileName,
  });

  final RecordImagePickProgressPhase phase;
  final int current;
  final int total;
  final String? fileName;

  String get message {
    return switch (phase) {
      RecordImagePickProgressPhase.selectingAndConverting =>
        '写真を選択・変換しています。',
      RecordImagePickProgressPhase.readingFiles =>
        fileName == null || fileName!.isEmpty
            ? '写真を読み込んでいます（$current/$total）。'
            : '写真を読み込んでいます（$current/$total）：$fileName',
    };
  }
}

typedef RecordImagePickProgressCallback =
    void Function(RecordImagePickProgress progress);

abstract interface class RecordImagePickerService {
  Future<List<RecordDraftPhoto>> pickImages();
}

abstract interface class RecordImagePickerProgressService {
  Future<List<RecordDraftPhoto>> pickImagesWithProgress({
    required RecordImagePickProgressCallback onProgress,
  });
}

class ImagePickerRecordImageService
    implements RecordImagePickerService, RecordImagePickerProgressService {
  ImagePickerRecordImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<RecordDraftPhoto>> pickImages() {
    return pickImagesWithProgress(onProgress: (_) {});
  }

  @override
  Future<List<RecordDraftPhoto>> pickImagesWithProgress({
    required RecordImagePickProgressCallback onProgress,
  }) async {
    onProgress(
      const RecordImagePickProgress(
        phase: RecordImagePickProgressPhase.selectingAndConverting,
      ),
    );

    final List<XFile> files = await _picker.pickMultiImage(
      maxWidth: AppConfig.recordImageMaxDimension.toDouble(),
      maxHeight: AppConfig.recordImageMaxDimension.toDouble(),
      imageQuality: AppConfig.recordImageQuality,
      requestFullMetadata: false,
    );

    final List<RecordDraftPhoto> photos = <RecordDraftPhoto>[];

    for (int index = 0; index < files.length; index += 1) {
      final XFile file = files[index];
      onProgress(
        RecordImagePickProgress(
          phase: RecordImagePickProgressPhase.readingFiles,
          current: index + 1,
          total: files.length,
          fileName: file.name,
        ),
      );
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
