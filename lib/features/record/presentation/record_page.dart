import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/building.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/models/record_submission_result.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../data/services/record_location_service.dart';
import '../../../data/services/record_submission_api_service.dart';
import '../../../data/services/tag_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../auth/presentation/google_sign_in_button.dart';
import '../controllers/record_draft_controller.dart';
import 'map_location_picker_page.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({
    required this.authService,
    this.imagePickerService,
    this.bootstrapApiService,
    this.locationService,
    this.tagApiService,
    this.recordSubmissionApiService,
    this.initialExistingBuildingId,
    super.key,
  });

  final AuthService authService;
  final RecordImagePickerService? imagePickerService;
  final BootstrapApiService? bootstrapApiService;
  final RecordLocationService? locationService;
  final TagApiService? tagApiService;
  final RecordSubmissionApiService? recordSubmissionApiService;
  final String? initialExistingBuildingId;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;
  late final RecordLocationService _locationService;
  late final TagApiService _tagApiService;
  late final bool _ownsTagApiService;
  late final RecordSubmissionApiService _recordSubmissionApiService;
  late final bool _ownsRecordSubmissionApiService;
  late final RecordDraftController _controller;

  @override
  void initState() {
    super.initState();
    _ownsBootstrapApiService = widget.bootstrapApiService == null;
    _bootstrapApiService =
        widget.bootstrapApiService ?? HttpBootstrapApiService();
    _locationService =
        widget.locationService ?? GeolocatorRecordLocationService();
    _ownsTagApiService = widget.tagApiService == null;
    _tagApiService = widget.tagApiService ?? HttpTagApiService();
    _ownsRecordSubmissionApiService = widget.recordSubmissionApiService == null;
    _recordSubmissionApiService =
        widget.recordSubmissionApiService ?? HttpRecordSubmissionApiService();
    _controller = RecordDraftController(
      imagePickerService:
          widget.imagePickerService ?? ImagePickerRecordImageService(),
      bootstrapApiService: _bootstrapApiService,
      authService: widget.authService,
      locationService: _locationService,
      tagApiService: _tagApiService,
      recordSubmissionApiService: _recordSubmissionApiService,
    );
    unawaited(_loadInitialData());
  }

  Future<void> _loadInitialData() async {
    await _controller.loadBootstrapData();

    if (!mounted) {
      return;
    }

    final String? buildingId = widget.initialExistingBuildingId?.trim();

    if (buildingId == null || buildingId.isEmpty) {
      return;
    }

    _controller.selectExistingBuilding(buildingId);

    if (_controller.selectedExistingBuilding != null) {
      _controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsBootstrapApiService) {
      _bootstrapApiService.close();
    }
    if (_ownsTagApiService) {
      _tagApiService.close();
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
          title: const Text('写真をすべて削除しますか？'),
          content: const Text('この画面で選択した写真の下書きが空になります。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('すべて削除'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      _controller.clearPhotos();
    }
  }

  Future<void> _showAddTagInput(BuildingTagType type) async {
    if (MediaQuery.sizeOf(context).width < 600) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: _AddTagForm(
              type: type,
              controller: _controller,
              showHeading: true,
            ),
          );
        },
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${type.displayName}タグを追加'),
          content: SizedBox(
            width: 420,
            child: _AddTagForm(
              type: type,
              controller: _controller,
              showHeading: false,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMapLocationPicker() async {
    if (_controller.isDraftLocked) {
      return;
    }

    final Building? selectedBuilding = _controller.selectedExistingBuilding;
    final RecordDraftLocation? selectedLocation = await Navigator.of(context)
        .push<RecordDraftLocation>(
          MaterialPageRoute<RecordDraftLocation>(
            builder: (BuildContext context) {
              return MapLocationPickerPage(
                initialLatitude: selectedBuilding?.latitude,
                initialLongitude: selectedBuilding?.longitude,
                locationService: _locationService,
              );
            },
          ),
        );

    if (!mounted || selectedLocation == null) {
      return;
    }

    _controller.useManualLocation(
      latitude: selectedLocation.latitude,
      longitude: selectedLocation.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '建築を記録する',
        showVersion: true,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_controller.requiresReauthentication) ...<Widget>[
                        _ReauthenticationPanel(controller: _controller),
                        const SizedBox(height: 20),
                      ],
                      KeyedSubtree(
                        key: ValueKey<int>(_controller.draftRevision),
                        child: _DraftLock(
                          locked: _controller.isDraftLocked,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _DraftHeader(
                                isPicking: _controller.isPicking,
                                hasPhotos: _controller.hasPhotos,
                                onAddPhotos: _controller.addPhotos,
                                onClearPhotos: _confirmClearPhotos,
                              ),
                              if (_controller.errorMessage != null) ...<Widget>[
                                const SizedBox(height: 12),
                                _MessagePanel(
                                  icon: Icons.error_outline,
                                  message: _controller.errorMessage!,
                                  isError: true,
                                ),
                              ],
                              if (_controller.noticeMessage !=
                                  null) ...<Widget>[
                                const SizedBox(height: 12),
                                _MessagePanel(
                                  icon: Icons.check_circle_outline,
                                  message: _controller.noticeMessage!,
                                ),
                              ],
                              const SizedBox(height: 20),
                              if (_controller.hasPhotos)
                                _PhotoDraftSection(
                                  photos: _controller.photos,
                                  totalBytes: _controller.totalBytes,
                                  onRemovePhoto: _controller.removePhoto,
                                )
                              else
                                const _EmptyDraftPanel(),
                              const SizedBox(height: 24),
                              _BuildingDraftSection(
                                controller: _controller,
                                onAddTag: _showAddTagInput,
                              ),
                              const SizedBox(height: 24),
                              _VisitDraftSection(
                                controller: _controller,
                                onAddTag: _showAddTagInput,
                                onPickMapLocation: _showMapLocationPicker,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _RecordSaveSection(controller: _controller),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DraftLock extends StatelessWidget {
  const _DraftLock({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: locked,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: locked ? 0.72 : 1,
        child: child,
      ),
    );
  }
}

class _RecordSaveSection extends StatelessWidget {
  const _RecordSaveSection({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool showPhotoProgress =
        controller.isDraftLocked && controller.photos.isNotEmpty;
    final String submitButtonLabel;
    if (controller.submissionPhase == RecordSubmissionPhase.failed) {
      submitButtonLabel = controller.failedPhotoCount > 0
          ? '失敗した写真を再送'
          : '保存を再試行';
    } else if (controller.isSubmitting) {
      submitButtonLabel = '保存しています';
    } else {
      submitButtonLabel = '記録を保存';
    }

    return Card(
      key: const Key('record-save-section'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_upload_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '記録を保存',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('建物と訪問を準備し、複数写真は最大2枚ずつ並行して非公開Driveへ保存します。'),
            const SizedBox(height: 16),
            _SubmissionStatusPanel(controller: controller),
            if (showPhotoProgress) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value:
                    controller.submissionPhase ==
                            RecordSubmissionPhase.starting ||
                        controller.submissionPhase ==
                            RecordSubmissionPhase.finalizing
                    ? null
                    : controller.submissionProgress,
              ),
              const SizedBox(height: 8),
              Text(
                '写真 ${controller.uploadedPhotoCount}/${controller.photoCount}枚を送信済み',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ...controller.photos.map((RecordDraftPhoto photo) {
                return _PhotoUploadProgressRow(
                  photo: photo,
                  status: controller.photoUploadStatus(photo.photoId),
                  performance: controller
                      .photoUploadResult(photo.photoId)
                      ?.performance,
                );
              }),
            ],
            if (controller.lastSubmissionDuration != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '今回の保存処理：${_formatElapsed(controller.lastSubmissionDuration!)}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            _UploadPerformanceDetails(controller: controller),
            if (controller.submissionErrorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.error_outline, color: colors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.submissionErrorMessage!,
                            style: TextStyle(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (controller.submissionErrorDetail != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        controller.submissionErrorDetail!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (controller.submissionNoticeMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.submissionNoticeMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (controller.submissionSucceeded)
              FilledButton.icon(
                key: const Key('start-new-record'),
                onPressed: controller.startNewRecord,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新しい記録を始める'),
              )
            else
              FilledButton.icon(
                key: const Key('submit-record'),
                onPressed: controller.canSubmitRecord
                    ? controller.submitRecord
                    : null,
                icon: controller.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        controller.submissionPhase ==
                                RecordSubmissionPhase.failed
                            ? Icons.refresh_outlined
                            : Icons.cloud_upload_outlined,
                      ),
                label: Text(submitButtonLabel),
              ),
            if (controller.isDraftLocked && !controller.submissionSucceeded)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '送信開始後は下書きを変更せず、同じボタンから再送してください。',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionStatusPanel extends StatelessWidget {
  const _SubmissionStatusPanel({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String label}) details =
        switch (controller.submissionPhase) {
          RecordSubmissionPhase.idle => (
            icon: Icons.edit_note_outlined,
            label: '下書きの入力内容を確認してください。',
          ),
          RecordSubmissionPhase.starting => (
            icon: Icons.inventory_2_outlined,
            label: '建物と訪問の保存準備をしています。',
          ),
          RecordSubmissionPhase.uploading => (
            icon: Icons.photo_library_outlined,
            label: '写真を最大2枚ずつ送信しています。',
          ),
          RecordSubmissionPhase.finalizing => (
            icon: Icons.fact_check_outlined,
            label: '保存枚数を確認して記録を確定しています。',
          ),
          RecordSubmissionPhase.failed => (
            icon: Icons.sync_problem_outlined,
            label: '入力内容と送信済み写真を保持しています。',
          ),
          RecordSubmissionPhase.succeeded => (
            icon: Icons.task_alt_outlined,
            label: '記録の保存が完了しました。',
          ),
        };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(details.icon),
          const SizedBox(width: 10),
          Expanded(child: Text(details.label)),
        ],
      ),
    );
  }
}

class _PhotoUploadProgressRow extends StatelessWidget {
  const _PhotoUploadProgressRow({
    required this.photo,
    required this.status,
    required this.performance,
  });

  final RecordDraftPhoto photo;
  final RecordPhotoUploadStatus status;
  final RecordUploadPerformance? performance;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String label}) details = switch (status) {
      RecordPhotoUploadStatus.pending => (
        icon: Icons.schedule_outlined,
        label: '未送信',
      ),
      RecordPhotoUploadStatus.uploading => (
        icon: Icons.sync_outlined,
        label: '送信中',
      ),
      RecordPhotoUploadStatus.uploaded => (
        icon: Icons.check_circle_outline,
        label: '送信済み',
      ),
      RecordPhotoUploadStatus.failed => (
        icon: Icons.error_outline,
        label: '再送待ち',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(details.icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              photo.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status == RecordPhotoUploadStatus.uploaded && performance != null
                ? '${details.label} ${_formatElapsed(performance!.clientTotalDuration)}'
                : details.label,
          ),
        ],
      ),
    );
  }
}

class _UploadPerformanceDetails extends StatelessWidget {
  const _UploadPerformanceDetails({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final List<({RecordDraftPhoto photo, RecordUploadPerformance performance})>
    entries =
        <({RecordDraftPhoto photo, RecordUploadPerformance performance})>[];

    for (final RecordDraftPhoto photo in controller.photos) {
      final RecordUploadPerformance? performance = controller
          .photoUploadResult(photo.photoId)
          ?.performance;
      if (performance != null) {
        entries.add((photo: photo, performance: performance));
      }
    }

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          key: const Key('record-upload-performance'),
          title: const Text('送信時間の内訳'),
          subtitle: const Text('通信・認証・Drive保存などを確認できます。'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: entries.map((entry) {
            final RecordUploadPerformance performance = entry.performance;
            final List<String> serverDetails = <String>[
              if (performance.authenticationMode != null)
                '認証 ${_authenticationModeLabel(performance.authenticationMode!)}',
              if (performance.authenticationMs != null)
                '認証処理 ${_formatMilliseconds(performance.authenticationMs!)}',
              if (performance.draftPreparationMs != null &&
                  performance.draftPreparationMs! > 0)
                '準備 ${_formatMilliseconds(performance.draftPreparationMs!)}',
              if (performance.lookupMs != null)
                '検索 ${_formatMilliseconds(performance.lookupMs!)}',
              if (performance.driveSaveMs != null)
                'Drive ${_formatMilliseconds(performance.driveSaveMs!)}',
              if (performance.sheetWriteMs != null)
                'Sheets ${_formatMilliseconds(performance.sheetWriteMs!)}',
              if (performance.finalizeMs != null && performance.finalizeMs! > 0)
                '確定 ${_formatMilliseconds(performance.finalizeMs!)}',
              if (performance.handlerTotalMs != null)
                'サーバー合計 ${_formatMilliseconds(performance.handlerTotalMs!)}',
            ];

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    entry.photo.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ブラウザ変換 ${_formatMilliseconds(performance.clientEncodeMs)} / '
                    '通信全体 ${_formatMilliseconds(performance.clientRequestMs)}',
                  ),
                  if (serverDetails.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(serverDetails.join(' / ')),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

String _formatElapsed(Duration duration) {
  return _formatMilliseconds(duration.inMilliseconds);
}

String _formatMilliseconds(int milliseconds) {
  if (milliseconds < 1000) {
    return '$milliseconds ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)}秒';
}

String _authenticationModeLabel(String mode) {
  return switch (mode) {
    'cache' => 'キャッシュ',
    'tokeninfo' => 'tokeninfo',
    _ => mode,
  };
}

class _DraftHeader extends StatelessWidget {
  const _DraftHeader({
    required this.isPicking,
    required this.hasPhotos,
    required this.onAddPhotos,
    required this.onClearPhotos,
  });

  final bool isPicking;
  final bool hasPhotos;
  final VoidCallback onAddPhotos;
  final VoidCallback onClearPhotos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '写真の下書き',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('建築の写真を複数選択できます。選択した写真は送信前の下書きとして、この画面内だけに保持します。'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '「記録を保存」を押すまでは写真・建物・訪問を送信しません。新しく追加したタグだけはタグマスターへ保存されます。',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('select-record-photos'),
                  onPressed: isPicking ? null : onAddPhotos,
                  icon: isPicking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    isPicking
                        ? '写真を読み込んでいます'
                        : hasPhotos
                        ? '写真を追加する'
                        : '写真を選択する',
                  ),
                ),
                if (hasPhotos)
                  OutlinedButton.icon(
                    key: const Key('clear-record-photos'),
                    onPressed: isPicking ? null : onClearPhotos,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('すべて削除'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingDraftSection extends StatelessWidget {
  const _BuildingDraftSection({
    required this.controller,
    required this.onAddTag,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.apartment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '建物の指定',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('新しい建物を登録するか、登録済みの建物へ今回の訪問を追加するかを選びます。'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const Key('record-building-mode-new'),
                  selected:
                      controller.buildingMode == RecordBuildingMode.newBuilding,
                  onSelected: (bool selected) {
                    if (selected) {
                      controller.setBuildingMode(
                        RecordBuildingMode.newBuilding,
                      );
                    }
                  },
                  avatar: const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('新しい建物'),
                ),
                ChoiceChip(
                  key: const Key('record-building-mode-existing'),
                  selected:
                      controller.buildingMode ==
                      RecordBuildingMode.existingBuilding,
                  onSelected: (bool selected) {
                    if (selected) {
                      controller.setBuildingMode(
                        RecordBuildingMode.existingBuilding,
                      );
                    }
                  },
                  avatar: const Icon(Icons.search_outlined, size: 18),
                  label: const Text('登録済みの建物'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.requiresReauthentication)
              const _BootstrapAuthenticationPausedPanel()
            else if (controller.isLoadingBootstrap)
              const _BootstrapLoadingPanel()
            else if (controller.bootstrapErrorMessage != null)
              _BootstrapErrorPanel(
                message: controller.bootstrapErrorMessage!,
                onRetry: () {
                  unawaited(controller.loadBootstrapData());
                },
              )
            else if (controller.hasLoadedBootstrap)
              controller.buildingMode == RecordBuildingMode.newBuilding
                  ? _NewBuildingDraftForm(
                      controller: controller,
                      onAddTag: onAddTag,
                    )
                  : _ExistingBuildingDraftForm(
                      controller: controller,
                      onAddTag: onAddTag,
                    )
            else
              const _BootstrapLoadingPanel(),
          ],
        ),
      ),
    );
  }
}

class _ReauthenticationPanel extends StatelessWidget {
  const _ReauthenticationPanel({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lock_clock_outlined, color: colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Googleログインの有効期限が切れました',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '選択した写真・建物・タグ・感想・位置はこの画面に保持されています。認証を更新すると、候補データを読み直して作業を続けられます。',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('refresh-record-authentication'),
              onPressed: controller.isRefreshingAuthentication
                  ? null
                  : () {
                      unawaited(controller.refreshAuthentication());
                    },
              icon: controller.isRefreshingAuthentication
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined),
              label: Text(
                controller.isRefreshingAuthentication
                    ? '認証を更新しています'
                    : '認証をもう一度更新',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '上の操作で戻らない場合は、下のGoogleボタンから同じアカウントでログインしてください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            const SizedBox(height: 10),
            Center(child: buildGoogleSignInButton()),
          ],
        ),
      ),
    );
  }
}

class _BootstrapAuthenticationPausedPanel extends StatelessWidget {
  const _BootstrapAuthenticationPausedPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.hourglass_top_outlined),
          SizedBox(width: 8),
          Expanded(child: Text('認証の更新後に、建物とタグの候補を自動で読み直します。')),
        ],
      ),
    );
  }
}

class _BootstrapLoadingPanel extends StatelessWidget {
  const _BootstrapLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(),
        SizedBox(height: 10),
        Text('建物とタグの候補を読み込んでいます。'),
      ],
    );
  }
}

class _BootstrapErrorPanel extends StatelessWidget {
  const _BootstrapErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: TextStyle(color: colors.onErrorContainer)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('retry-record-bootstrap'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }
}

class _NewBuildingDraftForm extends StatelessWidget {
  const _NewBuildingDraftForm({
    required this.controller,
    required this.onAddTag,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('new-building-name-field'),
          initialValue: controller.newBuildingName,
          onChanged: controller.setNewBuildingName,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '建物名',
            hintText: '例：○○ビル、△△工場',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        _TagSelectorAccordion(
          type: BuildingTagType.design,
          tags: controller.tagsFor(BuildingTagType.design),
          controller: controller,
          chipKeyPrefix: 'new-building-tag-design',
          onToggleTag: (String tagId) {
            controller.toggleBuildingTag(BuildingTagType.design, tagId);
          },
          onAddTag: () => onAddTag(BuildingTagType.design),
        ),
        const SizedBox(height: 16),
        _TagSelectorAccordion(
          type: BuildingTagType.sales,
          tags: controller.tagsFor(BuildingTagType.sales),
          controller: controller,
          chipKeyPrefix: 'new-building-tag-sales',
          onToggleTag: (String tagId) {
            controller.toggleBuildingTag(BuildingTagType.sales, tagId);
          },
          onAddTag: () => onAddTag(BuildingTagType.sales),
        ),
        const SizedBox(height: 16),
        _TagSelectorAccordion(
          type: BuildingTagType.construction,
          tags: controller.tagsFor(BuildingTagType.construction),
          controller: controller,
          chipKeyPrefix: 'new-building-tag-construction',
          onToggleTag: (String tagId) {
            controller.toggleBuildingTag(BuildingTagType.construction, tagId);
          },
          onAddTag: () => onAddTag(BuildingTagType.construction),
        ),
      ],
    );
  }
}

class _TagSelectorAccordion extends StatelessWidget {
  const _TagSelectorAccordion({
    required this.type,
    required this.tags,
    required this.controller,
    required this.chipKeyPrefix,
    required this.onToggleTag,
    required this.onAddTag,
    this.existingBuildingSelection = false,
    this.title,
    this.scopeLabel,
  });

  final BuildingTagType type;
  final List<BuildingTag> tags;
  final RecordDraftController controller;
  final String chipKeyPrefix;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddTag;
  final bool existingBuildingSelection;
  final String? title;
  final String? scopeLabel;

  @override
  Widget build(BuildContext context) {
    final List<BuildingTag> selectedTags = existingBuildingSelection
        ? controller.selectedExistingBuildingTagsFor(type)
        : controller.selectedTagsFor(type);
    final String selectionSummary = selectedTags.isEmpty
        ? '未選択'
        : selectedTags.map((BuildingTag tag) => tag.tagName).join('、');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>('tag-selector-${type.apiValue}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        title: Text(
          title ?? '${type.displayName}タグ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(scopeLabel ?? type.scopeLabel),
            const SizedBox(height: 2),
            Text(
              selectionSummary,
              key: Key('selected-tag-summary-${type.apiValue}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selectedTags.isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
                fontWeight: selectedTags.isEmpty
                    ? FontWeight.w400
                    : FontWeight.w600,
              ),
            ),
          ],
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: tags.isEmpty
                ? const Text('登録済みの候補がありません。')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map((BuildingTag tag) {
                          return FilterChip(
                            key: Key('$chipKeyPrefix-${tag.tagId}'),
                            selected: existingBuildingSelection
                                ? controller.isExistingBuildingTagSelected(
                                    type,
                                    tag.tagId,
                                  )
                                : controller.isTagSelected(type, tag.tagId),
                            onSelected: (bool selected) =>
                                onToggleTag(tag.tagId),
                            label: Text(tag.tagName),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: Key('add-tag-${type.apiValue}'),
              onPressed: controller.isCreatingTag(type) ? null : onAddTag,
              icon: controller.isCreatingTag(type)
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_outlined),
              label: const Text('新しいタグを追加'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTagForm extends StatefulWidget {
  const _AddTagForm({
    required this.type,
    required this.controller,
    required this.showHeading,
  });

  final BuildingTagType type;
  final RecordDraftController controller;
  final bool showHeading;

  @override
  State<_AddTagForm> createState() => _AddTagFormState();
}

class _AddTagFormState extends State<_AddTagForm> {
  final TextEditingController _nameController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String? error = await widget.controller.createAndSelectTag(
      widget.type,
      _nameController.text,
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showHeading) ...<Widget>[
          Text(
            '${widget.type.displayName}タグを追加',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: Key('new-tag-name-${widget.type.apiValue}'),
          controller: _nameController,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'タグ名',
            hintText: '例：設計研修 第一室',
            border: const OutlineInputBorder(),
            errorText: _errorMessage,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '追加したタグはタグマスターへ保存され、今回の記録で自動選択されます。タグはIDで管理し、名称変更は既存記録の表示にも反映する方針です。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: Key('submit-create-tag-${widget.type.apiValue}'),
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_outlined),
              label: const Text('追加して選択'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExistingBuildingDraftForm extends StatelessWidget {
  const _ExistingBuildingDraftForm({
    required this.controller,
    required this.onAddTag,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;

  @override
  Widget build(BuildContext context) {
    final List<Building> filteredBuildings = controller.filteredBuildings;
    final Building? selectedBuilding = controller.selectedExistingBuilding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const Key('existing-building-search-field'),
          initialValue: controller.buildingSearchQuery,
          onChanged: controller.setBuildingSearchQuery,
          decoration: const InputDecoration(
            labelText: '建物を検索',
            hintText: '建物名・住所で絞り込み',
            prefixIcon: Icon(Icons.search_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (controller.buildings.isEmpty)
          const _EmptyBuildingPanel(message: '登録済みの建物はまだありません。')
        else if (filteredBuildings.isEmpty)
          const _EmptyBuildingPanel(message: '検索条件に一致する建物がありません。')
        else
          Column(
            children: <Widget>[
              for (final Building building in filteredBuildings.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: Key(
                        'existing-building-option-${building.buildingId}',
                      ),
                      selected:
                          selectedBuilding?.buildingId == building.buildingId,
                      onTap: () {
                        controller.selectExistingBuilding(building.buildingId);
                      },
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(building.buildingName),
                      subtitle: building.address == null
                          ? null
                          : Text(building.address!),
                      trailing:
                          selectedBuilding?.buildingId == building.buildingId
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              if (filteredBuildings.length > 20)
                const Text('先頭20件を表示しています。検索文字を追加してください。'),
            ],
          ),
        if (selectedBuilding != null) ...<Widget>[
          const SizedBox(height: 16),
          _SelectedExistingBuildingCard(
            building: selectedBuilding,
            controller: controller,
            onAddTag: onAddTag,
          ),
        ],
      ],
    );
  }
}

class _EmptyBuildingPanel extends StatelessWidget {
  const _EmptyBuildingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.apartment_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SelectedExistingBuildingCard extends StatelessWidget {
  const _SelectedExistingBuildingCard({
    required this.building,
    required this.controller,
    required this.onAddTag,
  });

  final Building building;
  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('selected-existing-building-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '選択中の建物',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            building.buildingName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (building.address != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(building.address!),
          ],
          const SizedBox(height: 12),
          const Row(
            children: <Widget>[
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 6),
              Expanded(child: Text('登録済みタグの削除・変更はできません。追加するタグは下で選べます。')),
            ],
          ),
          const SizedBox(height: 12),
          _ReadOnlyTagGroup(
            label: '設計タグ',
            values: controller.tagNamesForIds(building.designTags),
          ),
          const SizedBox(height: 10),
          _ReadOnlyTagGroup(
            label: '営業タグ',
            values: controller.tagNamesForIds(building.salesTags),
          ),
          const SizedBox(height: 10),
          _ReadOnlyTagGroup(
            label: '施工タグ',
            values: controller.tagNamesForIds(building.constructionTags),
          ),
          const SizedBox(height: 18),
          Text(
            'この建物へタグを追加',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text('今回の保存時に、この建物へ追加するタグを選びます。'),
          const SizedBox(height: 12),
          _TagSelectorAccordion(
            type: BuildingTagType.design,
            tags: controller.tagsFor(BuildingTagType.design),
            controller: controller,
            chipKeyPrefix: 'existing-building-tag-design',
            onToggleTag: (String tagId) {
              controller.toggleExistingBuildingTag(
                BuildingTagType.design,
                tagId,
              );
            },
            onAddTag: () => onAddTag(BuildingTagType.design),
            existingBuildingSelection: true,
            title: '追加する設計タグ',
            scopeLabel: '既存建物へ追加予定',
          ),
          const SizedBox(height: 12),
          _TagSelectorAccordion(
            type: BuildingTagType.sales,
            tags: controller.tagsFor(BuildingTagType.sales),
            controller: controller,
            chipKeyPrefix: 'existing-building-tag-sales',
            onToggleTag: (String tagId) {
              controller.toggleExistingBuildingTag(
                BuildingTagType.sales,
                tagId,
              );
            },
            onAddTag: () => onAddTag(BuildingTagType.sales),
            existingBuildingSelection: true,
            title: '追加する営業タグ',
            scopeLabel: '既存建物へ追加予定',
          ),
          const SizedBox(height: 12),
          _TagSelectorAccordion(
            type: BuildingTagType.construction,
            tags: controller.tagsFor(BuildingTagType.construction),
            controller: controller,
            chipKeyPrefix: 'existing-building-tag-construction',
            onToggleTag: (String tagId) {
              controller.toggleExistingBuildingTag(
                BuildingTagType.construction,
                tagId,
              );
            },
            onAddTag: () => onAddTag(BuildingTagType.construction),
            existingBuildingSelection: true,
            title: '追加する施工タグ',
            scopeLabel: '既存建物へ追加予定',
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyTagGroup extends StatelessWidget {
  const _ReadOnlyTagGroup({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (values.isEmpty)
          const Text('未登録')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map((String value) => Chip(label: Text(value)))
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _VisitDraftSection extends StatelessWidget {
  const _VisitDraftSection({
    required this.controller,
    required this.onAddTag,
    required this.onPickMapLocation,
  });

  final RecordDraftController controller;
  final ValueChanged<BuildingTagType> onAddTag;
  final VoidCallback onPickMapLocation;

  @override
  Widget build(BuildContext context) {
    final List<BuildingTag> triggerTags = controller.tagsFor(
      BuildingTagType.trigger,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.edit_note_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今回の訪問',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('訪問のきっかけ、感想、撮影した場所を下書きへ追加します。'),
            const SizedBox(height: 20),
            _TagSelectorAccordion(
              type: BuildingTagType.trigger,
              tags: triggerTags,
              controller: controller,
              chipKeyPrefix: 'visit-trigger-tag',
              onToggleTag: controller.toggleTriggerTag,
              onAddTag: () => onAddTag(BuildingTagType.trigger),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('visit-impression-field'),
              initialValue: controller.impression,
              onChanged: controller.setImpression,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '感想',
                hintText: '空間の印象、気づいた点、あとで調べたいことなど',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _VisitLocationPanel(
              controller: controller,
              onPickMapLocation: onPickMapLocation,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '複数写真は最大2枚ずつ送信します。途中で失敗した場合は、入力内容と送信済み写真を保持して失敗分だけ再送します。',
                    ),
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

class _VisitLocationPanel extends StatelessWidget {
  const _VisitLocationPanel({
    required this.controller,
    required this.onPickMapLocation,
  });

  final RecordDraftController controller;
  final VoidCallback onPickMapLocation;

  @override
  Widget build(BuildContext context) {
    final RecordDraftLocation? location = controller.visitLocation;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      key: const Key('visit-location-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.my_location_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                '位置情報',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.isGettingLocation) ...<Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text('現在地を取得しています。'),
          ] else if (location == null)
            const _LocationEmptyState()
          else
            _LocationValue(location: location),
          if (controller.locationErrorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineLocationMessage(
              message: controller.locationErrorMessage!,
              isError: true,
            ),
          ],
          if (controller.locationNoticeMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _InlineLocationMessage(message: controller.locationNoticeMessage!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('capture-current-location'),
                onPressed: controller.isGettingLocation
                    ? null
                    : controller.acquireCurrentLocation,
                icon: const Icon(Icons.gps_fixed_outlined),
                label: Text(location == null ? '現在地を取得' : '現在地を再取得'),
              ),
              OutlinedButton.icon(
                key: const Key('pick-location-on-map'),
                onPressed: controller.isGettingLocation
                    ? null
                    : onPickMapLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('地図で位置を指定'),
              ),
              if (controller.canUseSelectedBuildingLocation)
                OutlinedButton.icon(
                  key: const Key('use-building-location'),
                  onPressed: controller.isGettingLocation
                      ? null
                      : controller.useSelectedBuildingLocation,
                  icon: const Icon(Icons.apartment_outlined),
                  label: const Text('建物の代表位置を使う'),
                ),
              if (location != null)
                TextButton.icon(
                  key: const Key('clear-visit-location'),
                  onPressed: controller.isGettingLocation
                      ? null
                      : controller.clearVisitLocation,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('位置をクリア'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationEmptyState extends StatelessWidget {
  const _LocationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.location_off_outlined),
          SizedBox(width: 8),
          Expanded(child: Text('位置はまだ取得されていません。')),
        ],
      ),
    );
  }
}

class _LocationValue extends StatelessWidget {
  const _LocationValue({required this.location});

  final RecordDraftLocation location;

  @override
  Widget build(BuildContext context) {
    final String accuracyText = location.accuracyM == null
        ? '未設定'
        : '±${location.accuracyM!.toStringAsFixed(1)} m';

    return Container(
      key: const Key('visit-location-value'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LocationRow(label: '取得方法', value: location.source.displayName),
          const SizedBox(height: 6),
          _LocationRow(
            label: '緯度',
            value: location.latitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 6),
          _LocationRow(
            label: '経度',
            value: location.longitude.toStringAsFixed(6),
          ),
          const SizedBox(height: 6),
          _LocationRow(label: '精度', value: accuracyText),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _InlineLocationMessage extends StatelessWidget {
  const _InlineLocationMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.secondaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = isError
        ? colors.errorContainer
        : colors.primaryContainer;
    final Color foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

class _EmptyDraftPanel extends StatelessWidget {
  const _EmptyDraftPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.photo_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '写真がまだ選択されていません',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '「写真を選択する」から、今回の訪問で記録する写真を追加してください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoDraftSection extends StatelessWidget {
  const _PhotoDraftSection({
    required this.photos,
    required this.totalBytes,
    required this.onRemovePhoto,
  });

  final List<RecordDraftPhoto> photos;
  final int totalBytes;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                _SummaryValue(
                  key: const Key('record-photo-count'),
                  icon: Icons.photo_library_outlined,
                  label: '選択枚数',
                  value: '${photos.length}枚',
                ),
                _SummaryValue(
                  key: const Key('record-total-size'),
                  icon: Icons.data_usage_outlined,
                  label: '合計容量',
                  value: _formatBytes(totalBytes),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columnCount;
            if (constraints.maxWidth >= 900) {
              columnCount = 4;
            } else if (constraints.maxWidth >= 620) {
              columnCount = 3;
            } else {
              columnCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (BuildContext context, int index) {
                final RecordDraftPhoto photo = photos[index];
                return _DraftPhotoCard(
                  key: ValueKey<String>('draft-photo-${photo.photoId}'),
                  photo: photo,
                  onRemove: () => onRemovePhoto(photo.photoId),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _DraftPhotoCard extends StatelessWidget {
  const _DraftPhotoCard({
    required this.photo,
    required this.onRemove,
    super.key,
  });

  final RecordDraftPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Image.memory(
              photo.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    );
                  },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        photo.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatBytes(photo.byteSize),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('remove-draft-photo-${photo.photoId}'),
                  onPressed: onRemove,
                  tooltip: '${photo.fileName}を削除',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int byteSize) {
  if (byteSize < 1024) {
    return '$byteSize B';
  }

  final double kilobytes = byteSize / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }

  final double megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} MB';
}
