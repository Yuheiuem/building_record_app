import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/services/record_image_picker_service.dart';

class RecordDraftController extends ChangeNotifier {
  RecordDraftController({required RecordImagePickerService imagePickerService})
    : _imagePickerService = imagePickerService;

  final RecordImagePickerService _imagePickerService;
  final List<RecordDraftPhoto> _photos = <RecordDraftPhoto>[];

  bool _isPicking = false;
  String? _errorMessage;
  String? _noticeMessage;

  UnmodifiableListView<RecordDraftPhoto> get photos =>
      UnmodifiableListView<RecordDraftPhoto>(_photos);

  bool get isPicking => _isPicking;
  bool get hasPhotos => _photos.isNotEmpty;
  int get photoCount => _photos.length;
  int get totalBytes => _photos.fold<int>(
    0,
    (int total, RecordDraftPhoto photo) => total + photo.byteSize,
  );
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  Future<void> addPhotos() async {
    if (_isPicking) {
      return;
    }

    _isPicking = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final List<RecordDraftPhoto> selectedPhotos = await _imagePickerService
          .pickImages();

      if (selectedPhotos.isEmpty) {
        return;
      }

      final List<RecordDraftPhoto> acceptedPhotos = <RecordDraftPhoto>[];
      int unsupportedCount = 0;
      int oversizedCount = 0;

      for (final RecordDraftPhoto photo in selectedPhotos) {
        if (!photo.isSupportedImage) {
          unsupportedCount += 1;
          continue;
        }

        if (photo.byteSize > AppConfig.recordMaxPhotoBytes) {
          oversizedCount += 1;
          continue;
        }

        acceptedPhotos.add(photo);
      }

      _photos.addAll(acceptedPhotos);

      if (unsupportedCount > 0 || oversizedCount > 0) {
        final List<String> reasons = <String>[];

        if (unsupportedCount > 0) {
          reasons.add('未対応形式 $unsupportedCount枚');
        }

        if (oversizedCount > 0) {
          reasons.add('5MB超過 $oversizedCount枚');
        }

        _errorMessage = '${reasons.join('、')}は追加しませんでした。';
      }

      if (acceptedPhotos.isNotEmpty) {
        _noticeMessage = '${acceptedPhotos.length}枚を下書きへ追加しました。';
      }
    } catch (_) {
      _errorMessage = '写真を選択できませんでした。もう一度お試しください。';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  void removePhoto(String photoId) {
    final int removedCount = _photos.length;
    _photos.removeWhere((RecordDraftPhoto photo) => photo.photoId == photoId);

    if (_photos.length == removedCount) {
      return;
    }

    _errorMessage = null;
    _noticeMessage = '写真を1枚削除しました。';
    notifyListeners();
  }

  void clearPhotos() {
    if (_photos.isEmpty) {
      return;
    }

    _photos.clear();
    _errorMessage = null;
    _noticeMessage = '写真の下書きを空にしました。';
    notifyListeners();
  }
}
