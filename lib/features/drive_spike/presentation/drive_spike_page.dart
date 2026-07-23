import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/drive_spike_photo.dart';
import '../../../data/models/selected_spike_image.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/drive_spike_api_service.dart';
import '../../../data/services/google_auth_service.dart';
import '../../../data/services/spike_image_picker_service.dart';
import '../../auth/presentation/google_sign_in_button.dart';

class DriveSpikePage extends StatefulWidget {
  const DriveSpikePage({
    super.key,
    this.authService,
    this.driveApiService,
    this.imagePickerService,
  });

  final AuthService? authService;
  final DriveSpikeApiService? driveApiService;
  final SpikeImagePickerService? imagePickerService;

  @override
  State<DriveSpikePage> createState() => _DriveSpikePageState();
}

class _DriveSpikePageState extends State<DriveSpikePage> {
  late final AuthService _authService;
  late final DriveSpikeApiService _driveApiService;
  late final SpikeImagePickerService _imagePickerService;
  late final bool _ownsDriveApiService;

  SelectedSpikeImage? _selectedImage;
  DriveSpikeUploadResponse? _uploadResponse;
  DriveSpikePhotoData? _downloadedPhoto;
  String? _errorMessage;
  bool _isSelecting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? GoogleAuthService.instance;
    _ownsDriveApiService = widget.driveApiService == null;
    _driveApiService = widget.driveApiService ?? HttpDriveSpikeApiService();
    _imagePickerService =
        widget.imagePickerService ?? ImagePickerSpikeService();
    _authService.addListener(_handleAuthChanged);
    unawaited(_authService.initialize());
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }

    if (_authService.status != GoogleAuthStatus.signedIn) {
      _clearPhotoState();
    }
    setState(() {});
  }

  void _clearPhotoState() {
    _selectedImage = null;
    _uploadResponse = null;
    _downloadedPhoto = null;
    _errorMessage = null;
    _isSelecting = false;
    _isSaving = false;
  }

  Future<void> _selectImage() async {
    if (_isSelecting || _isSaving) {
      return;
    }

    setState(() {
      _isSelecting = true;
      _errorMessage = null;
      _uploadResponse = null;
      _downloadedPhoto = null;
    });

    try {
      final SelectedSpikeImage? image = await _imagePickerService
          .pickSingleImage();
      if (!mounted || image == null) {
        return;
      }

      if (image.mimeType != 'image/jpeg' && image.mimeType != 'image/png') {
        throw const DriveSpikeUiException('JPEGまたはPNGの画像を選択してください。');
      }

      if (image.byteSize > AppConfig.driveSpikeMaxPhotoBytes) {
        throw DriveSpikeUiException(
          '画像が大きすぎます。${_formatBytes(AppConfig.driveSpikeMaxPhotoBytes)}以下の画像を選択してください。',
        );
      }

      setState(() {
        _selectedImage = image;
      });
    } on DriveSpikeUiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = '画像を選択できませんでした。もう一度お試しください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
      }
    }
  }

  Future<void> _saveAndReload() async {
    final SelectedSpikeImage? image = _selectedImage;
    final String? idToken = _authService.idToken;

    if (image == null || idToken == null || idToken.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _uploadResponse = null;
      _downloadedPhoto = null;
    });

    try {
      final String photoId = const Uuid().v4();
      final DriveSpikeUploadResponse uploadResponse = await _driveApiService
          .uploadPhoto(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: idToken,
            photoId: photoId,
            fileName: image.fileName,
            mimeType: image.mimeType,
            bytes: image.bytes,
          );

      final DriveSpikePhotoData downloadedPhoto = await _driveApiService
          .getPhoto(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: idToken,
            storageFileId: uploadResponse.storageFileId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadResponse = uploadResponse;
        _downloadedPhoto = downloadedPhoto;
      });
    } on DriveSpikeApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = '画像を保存・再表示できませんでした。もう一度お試しください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
    if (_ownsDriveApiService) {
      _driveApiService.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _AppHeader(),
                  const SizedBox(height: 24),
                  _StatusCard(
                    authService: _authService,
                    hasSelectedImage: _selectedImage != null,
                    uploadResponse: _uploadResponse,
                    downloadedPhoto: _downloadedPhoto,
                  ),
                  const SizedBox(height: 16),
                  _AuthPanel(authService: _authService),
                  const SizedBox(height: 16),
                  _DriveSpikePanel(
                    authService: _authService,
                    selectedImage: _selectedImage,
                    uploadResponse: _uploadResponse,
                    downloadedPhoto: _downloadedPhoto,
                    errorMessage: _errorMessage,
                    isSelecting: _isSelecting,
                    isSaving: _isSaving,
                    onSelectImage: _selectImage,
                    onSaveAndReload: _saveAndReload,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '画像本文・IDトークンはログやGitHubへ保存しません。Driveファイルは公開共有しません。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.version,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.apartment_outlined,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppConfig.workingTitle,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConfig.stage,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.authService,
    required this.hasSelectedImage,
    required this.uploadResponse,
    required this.downloadedPhoto,
  });

  final AuthService authService;
  final bool hasSelectedImage;
  final DriveSpikeUploadResponse? uploadResponse;
  final DriveSpikePhotoData? downloadedPhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '非公開Drive保存・再表示',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('認証済みアプリから画像を1枚保存し、公開URLを使わずに同じ画像を再取得します。'),
            const SizedBox(height: 20),
            _StatusRow(
              label: 'Googleログイン',
              value: authService.status == GoogleAuthStatus.signedIn
                  ? 'ログイン済み'
                  : '未ログイン',
              completed: authService.status == GoogleAuthStatus.signedIn,
            ),
            const Divider(height: 28),
            _StatusRow(
              label: '画像選択',
              value: hasSelectedImage ? '選択済み' : '未選択',
              completed: hasSelectedImage,
            ),
            const Divider(height: 28),
            _StatusRow(
              label: '非公開Drive保存',
              value: uploadResponse == null ? '未実行' : '保存成功',
              completed: uploadResponse != null,
            ),
            const Divider(height: 28),
            _StatusRow(
              label: '認証付き再表示',
              value: downloadedPhoto == null ? '未実行' : '再表示成功',
              completed: downloadedPhoto != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    if (authService.status == GoogleAuthStatus.initializing) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Googleログインを初期化しています。'),
            ],
          ),
        ),
      );
    }

    if (authService.status != GoogleAuthStatus.signedIn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              if (authService.errorMessage != null) ...<Widget>[
                Text(
                  authService.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              const Text('専用Googleアカウントでログインしてください。'),
              const SizedBox(height: 12),
              Center(child: buildGoogleSignInButton()),
            ],
          ),
        ),
      );
    }

    final AuthenticatedGoogleUser? user = authService.currentUser;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              user?.displayName ?? 'Googleアカウント',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(user?.email ?? ''),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: authService.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('ログアウト'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveSpikePanel extends StatelessWidget {
  const _DriveSpikePanel({
    required this.authService,
    required this.selectedImage,
    required this.uploadResponse,
    required this.downloadedPhoto,
    required this.errorMessage,
    required this.isSelecting,
    required this.isSaving,
    required this.onSelectImage,
    required this.onSaveAndReload,
  });

  final AuthService authService;
  final SelectedSpikeImage? selectedImage;
  final DriveSpikeUploadResponse? uploadResponse;
  final DriveSpikePhotoData? downloadedPhoto;
  final String? errorMessage;
  final bool isSelecting;
  final bool isSaving;
  final Future<void> Function() onSelectImage;
  final Future<void> Function() onSaveAndReload;

  @override
  Widget build(BuildContext context) {
    final bool signedIn = authService.status == GoogleAuthStatus.signedIn;
    final SelectedSpikeImage? image = selectedImage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Drive技術スパイク',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'JPEGまたはPNGを1枚選択してください。上限は${_formatBytes(AppConfig.driveSpikeMaxPhotoBytes)}です。',
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: signedIn && !isSelecting && !isSaving
                  ? onSelectImage
                  : null,
              icon: isSelecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(isSelecting ? '画像を選択中' : '画像を選択'),
            ),
            if (image != null) ...<Widget>[
              const SizedBox(height: 16),
              _ImagePreview(
                title: '選択した画像',
                bytes: image.bytes,
                details:
                    '${image.fileName} / ${image.mimeType} / ${_formatBytes(image.byteSize)}',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: signedIn && !isSaving ? onSaveAndReload : null,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(isSaving ? '保存・再取得中' : '非公開Driveへ保存して再表示'),
              ),
            ],
            if (uploadResponse != null) ...<Widget>[
              const SizedBox(height: 16),
              _ResultRow(
                label: 'Drive保存',
                value: uploadResponse!.duplicate ? '既存ファイルを再利用' : '新規保存',
              ),
              _ResultRow(label: '共有状態', value: uploadResponse!.sharingAccess),
              _ResultRow(label: 'サーバー時刻', value: uploadResponse!.serverTime),
            ],
            if (downloadedPhoto != null) ...<Widget>[
              const SizedBox(height: 16),
              _ImagePreview(
                title: 'Driveから認証付きで再取得した画像',
                bytes: downloadedPhoto!.bytes,
                details:
                    '${downloadedPhoto!.fileName} / ${downloadedPhoto!.mimeType} / ${_formatBytes(downloadedPhoto!.byteSize)}',
              ),
              const SizedBox(height: 8),
              _ResultRow(
                label: '再取得時の共有状態',
                value: downloadedPhoto!.sharingAccess,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.title,
    required this.bytes,
    required this.details,
  });

  final String title;
  final Uint8List bytes;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('画像を表示できませんでした。'),
                        );
                      },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(details, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.completed,
  });

  final String label;
  final String value;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color valueColor = completed
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Icon(
          completed ? Icons.check_circle : Icons.schedule,
          size: 18,
          color: valueColor,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class DriveSpikeUiException implements Exception {
  const DriveSpikeUiException(this.message);

  final String message;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes bytes';
}
