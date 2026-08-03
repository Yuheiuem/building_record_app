import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/building_detail_data.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/building_detail_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../data/services/record_submission_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../controllers/visit_photo_addition_controller.dart';

class VisitPhotoAdditionPage extends StatefulWidget {
  const VisitPhotoAdditionPage({
    required this.authService,
    required this.buildingId,
    required this.visitId,
    this.buildingDetailApiService,
    this.imagePickerService,
    this.recordSubmissionApiService,
    super.key,
  });

  final AuthService authService;
  final String buildingId;
  final String visitId;
  final BuildingDetailApiService? buildingDetailApiService;
  final RecordImagePickerService? imagePickerService;
  final RecordSubmissionApiService? recordSubmissionApiService;

  @override
  State<VisitPhotoAdditionPage> createState() =>
      _VisitPhotoAdditionPageState();
}

class _VisitPhotoAdditionPageState extends State<VisitPhotoAdditionPage> {
  late final BuildingDetailApiService _buildingDetailApiService;
  late final bool _ownsBuildingDetailApiService;
  late final RecordSubmissionApiService _recordSubmissionApiService;
  late final bool _ownsRecordSubmissionApiService;
  late final VisitPhotoAdditionController _controller;

  @override
  void initState() {
    super.initState();
    _ownsBuildingDetailApiService = widget.buildingDetailApiService == null;
    _buildingDetailApiService =
        widget.buildingDetailApiService ?? HttpBuildingDetailApiService();
    _ownsRecordSubmissionApiService =
        widget.recordSubmissionApiService == null;
    _recordSubmissionApiService =
        widget.recordSubmissionApiService ?? HttpRecordSubmissionApiService();

    _controller = VisitPhotoAdditionController(
      buildingId: widget.buildingId,
      visitId: widget.visitId,
      authService: widget.authService,
      buildingDetailApiService: _buildingDetailApiService,
      imagePickerService:
          widget.imagePickerService ?? ImagePickerRecordImageService(),
      recordSubmissionApiService: _recordSubmissionApiService,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_controller.loadDetail());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsBuildingDetailApiService) {
      _buildingDetailApiService.close();
    }
    if (_ownsRecordSubmissionApiService) {
      _recordSubmissionApiService.close();
    }
    super.dispose();
  }

  Future<void> _confirmClearPhotos() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('未送信の写真を削除しますか？'),
          content: const Text('すでに送信済みの写真は削除されません。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      _controller.clearUnsentPhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '訪問へ写真を追加',
        showVersion: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return _buildBody(context);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading && _controller.detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.detail == null || _controller.visit == null) {
      return _LoadErrorState(
        message: _controller.errorMessage ?? '訪問記録を取得できませんでした。',
        isRefreshingAuthentication: _controller.isRefreshingAuthentication,
        requiresReauthentication: _controller.requiresReauthentication,
        onRetry: _controller.loadDetail,
        onRefreshAuthentication: _controller.refreshAuthentication,
      );
    }

    final BuildingDetailData detail = _controller.detail!;
    final BuildingVisit visit = _controller.visit!;

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _VisitSummaryCard(detail: detail, visit: visit),
                  const SizedBox(height: 12),
                  if (_controller.errorMessage != null)
                    _MessageCard(
                      icon: Icons.error_outline,
                      message: _controller.errorMessage!,
                      detail: _controller.errorDetail,
                      isError: true,
                    ),
                  if (_controller.errorMessage != null)
                    const SizedBox(height: 12),
                  if (_controller.noticeMessage != null)
                    _MessageCard(
                      icon: Icons.info_outline,
                      message: _controller.noticeMessage!,
                    ),
                  if (_controller.noticeMessage != null)
                    const SizedBox(height: 12),
                  if (_controller.requiresReauthentication)
                    _AuthenticationRefreshCard(
                      isRefreshing: _controller.isRefreshingAuthentication,
                      onPressed: _controller.refreshAuthentication,
                    ),
                  if (_controller.requiresReauthentication)
                    const SizedBox(height: 12),
                  _PhotoSelectionCard(
                    controller: _controller,
                    onClear: _confirmClearPhotos,
                  ),
                  const SizedBox(height: 12),
                  _UploadCard(controller: _controller),
                ],
              ),
            ),
          ),
        ),
        if (_controller.isUploading || _controller.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({required this.detail, required this.visit});

  final BuildingDetailData detail;
  final BuildingVisit visit;

  @override
  Widget build(BuildContext context) {
    final String locationDescription;
    if (visit.latitude != null && visit.longitude != null) {
      locationDescription =
          '訪問位置 ${visit.latitude!.toStringAsFixed(6)}, '
          '${visit.longitude!.toStringAsFixed(6)}';
    } else if (detail.building.latitude != null &&
        detail.building.longitude != null) {
      locationDescription = '訪問位置がないため、建物代表位置を使用します。';
    } else {
      locationDescription = '写真へ設定できる位置情報がありません。';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail.building.buildingName,
                    key: const Key('visit-photo-addition-building-name'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '対象の訪問：${_formatDateTime(visit.visitedAt)}',
              key: const Key('visit-photo-addition-visited-at'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(locationDescription),
            const SizedBox(height: 6),
            Text(
              '追加写真には対象訪問の日時・位置情報を設定します。新しい訪問記録は作成しません。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSelectionCard extends StatelessWidget {
  const _PhotoSelectionCard({
    required this.controller,
    required this.onClear,
  });

  final VisitPhotoAdditionController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '追加する写真',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${controller.photoCount}枚'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('pick-visit-addition-photos'),
                  onPressed: controller.canAddPhotos
                      ? controller.addPhotos
                      : null,
                  icon: controller.isPicking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(controller.isPicking ? '選択中' : '写真を選択'),
                ),
                OutlinedButton.icon(
                  key: const Key('clear-visit-addition-photos'),
                  onPressed:
                      controller.photos.isNotEmpty && !controller.isUploading
                      ? onClear
                      : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('未送信をすべて削除'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '合計 ${_formatBytes(controller.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (controller.photos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.photo_outlined, size: 48),
                    SizedBox(height: 10),
                    Text('追加する写真を選択してください。'),
                  ],
                ),
              )
            else
              GridView.builder(
                key: const Key('visit-addition-photo-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                itemCount: controller.photos.length,
                itemBuilder: (BuildContext context, int index) {
                  final RecordDraftPhoto photo = controller.photos[index];
                  return _DraftPhotoTile(
                    photo: photo,
                    status: controller.uploadStatus(photo.photoId),
                    onRemove: () => controller.removePhoto(photo.photoId),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftPhotoTile extends StatelessWidget {
  const _DraftPhotoTile({
    required this.photo,
    required this.status,
    required this.onRemove,
  });

  final RecordDraftPhoto photo;
  final VisitPhotoAdditionUploadStatus status;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool removable =
        status == VisitPhotoAdditionUploadStatus.pending ||
        status == VisitPhotoAdditionUploadStatus.failed;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.memory(photo.bytes, fit: BoxFit.cover),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _UploadStatusChip(status: status),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      key: Key('remove-visit-addition-photo-${photo.photoId}'),
                      tooltip: '写真を削除',
                      onPressed: removable ? onRemove : null,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    photo.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatBytes(photo.byteSize),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadStatusChip extends StatelessWidget {
  const _UploadStatusChip({required this.status});

  final VisitPhotoAdditionUploadStatus status;

  @override
  Widget build(BuildContext context) {
    final (IconData, String) value = switch (status) {
      VisitPhotoAdditionUploadStatus.pending =>
        (Icons.schedule_outlined, '未送信'),
      VisitPhotoAdditionUploadStatus.uploading =>
        (Icons.cloud_upload_outlined, '送信中'),
      VisitPhotoAdditionUploadStatus.uploaded =>
        (Icons.check_circle_outline, '送信済み'),
      VisitPhotoAdditionUploadStatus.failed =>
        (Icons.error_outline, '失敗'),
    };

    return Chip(
      avatar: Icon(value.$1, size: 16),
      label: Text(value.$2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.controller});

  final VisitPhotoAdditionController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.succeeded) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 52),
              const SizedBox(height: 10),
              Text(
                '写真の追加が完了しました。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (controller.lastUploadDuration != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '保存処理 ${_formatDuration(controller.lastUploadDuration!)}',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('finish-visit-photo-addition'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.arrow_back),
                label: const Text('建物詳細へ戻る'),
              ),
            ],
          ),
        ),
      );
    }

    final String buttonLabel;
    if (controller.isUploading) {
      buttonLabel = '送信しています';
    } else if (controller.failedPhotoCount > 0) {
      buttonLabel = '失敗した写真を再送';
    } else {
      buttonLabel = '写真を追加して保存';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '保存',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: controller.photos.isEmpty
                  ? 0
                  : controller.uploadProgress,
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.uploadedPhotoCount}/${controller.photoCount}枚送信済み',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('submit-visit-photo-addition'),
              onPressed: controller.canUpload ? controller.uploadPhotos : null,
              icon: controller.isUploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticationRefreshCard extends StatelessWidget {
  const _AuthenticationRefreshCard({
    required this.isRefreshing,
    required this.onPressed,
  });

  final bool isRefreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('写真と送信済み状態を保持したまま、Google認証を更新します。'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: isRefreshing ? null : onPressed,
              icon: const Icon(Icons.refresh),
              label: Text(isRefreshing ? '認証を更新中' : '認証を更新'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    this.detail,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: isError ? colors.errorContainer : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(message),
                  if (detail != null && detail!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.message,
    required this.isRefreshingAuthentication,
    required this.requiresReauthentication,
    required this.onRetry,
    required this.onRefreshAuthentication,
  });

  final String message;
  final bool isRefreshingAuthentication;
  final bool requiresReauthentication;
  final VoidCallback onRetry;
  final VoidCallback onRefreshAuthentication;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 54),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (requiresReauthentication)
              FilledButton.icon(
                onPressed: isRefreshingAuthentication
                    ? null
                    : onRefreshAuthentication,
                icon: const Icon(Icons.refresh),
                label: Text(
                  isRefreshingAuthentication ? '認証を更新中' : '認証を更新',
                ),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('もう一度読み込む'),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final double kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

String _formatDuration(Duration duration) {
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}秒';
}
