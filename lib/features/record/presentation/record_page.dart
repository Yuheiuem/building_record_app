import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/building.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../controllers/record_draft_controller.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({
    required this.authService,
    this.imagePickerService,
    this.bootstrapApiService,
    super.key,
  });

  final AuthService authService;
  final RecordImagePickerService? imagePickerService;
  final BootstrapApiService? bootstrapApiService;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;
  late final RecordDraftController _controller;

  @override
  void initState() {
    super.initState();
    _ownsBootstrapApiService = widget.bootstrapApiService == null;
    _bootstrapApiService =
        widget.bootstrapApiService ?? HttpBootstrapApiService();
    _controller = RecordDraftController(
      imagePickerService:
          widget.imagePickerService ?? ImagePickerRecordImageService(),
      bootstrapApiService: _bootstrapApiService,
      authService: widget.authService,
    );
    unawaited(_controller.loadBootstrapData());
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsBootstrapApiService) {
      _bootstrapApiService.close();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '建築を記録する',
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
                      if (_controller.noticeMessage != null) ...<Widget>[
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
                      _BuildingDraftSection(controller: _controller),
                      const SizedBox(height: 24),
                      const AppVersionFooter(),
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
                      'この段階ではGoogle Sheets・Driveへ送信しません。写真と建物情報はブラウザを再読み込みすると消えます。',
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
  const _BuildingDraftSection({required this.controller});

  final RecordDraftController controller;

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
            if (controller.isLoadingBootstrap)
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
                  ? _NewBuildingDraftForm(controller: controller)
                  : _ExistingBuildingDraftForm(controller: controller)
            else
              const _BootstrapLoadingPanel(),
          ],
        ),
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
  const _NewBuildingDraftForm({required this.controller});

  final RecordDraftController controller;

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
        _EditableTagGroup(
          type: BuildingTagType.design,
          tags: controller.tagsFor(BuildingTagType.design),
          controller: controller,
        ),
        const SizedBox(height: 16),
        _EditableTagGroup(
          type: BuildingTagType.sales,
          tags: controller.tagsFor(BuildingTagType.sales),
          controller: controller,
        ),
        const SizedBox(height: 16),
        _EditableTagGroup(
          type: BuildingTagType.construction,
          tags: controller.tagsFor(BuildingTagType.construction),
          controller: controller,
        ),
        const SizedBox(height: 16),
        const _NextStageNotice(),
      ],
    );
  }
}

class _EditableTagGroup extends StatelessWidget {
  const _EditableTagGroup({
    required this.type,
    required this.tags,
    required this.controller,
  });

  final BuildingTagType type;
  final List<BuildingTag> tags;
  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${type.displayName}タグ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(type.scopeLabel, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const Text('登録済みの候補がありません。')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map((BuildingTag tag) {
                  return FilterChip(
                    key: Key('new-building-tag-${type.apiValue}-${tag.tagId}'),
                    selected: controller.isTagSelected(type, tag.tagId),
                    onSelected: (bool selected) {
                      controller.toggleBuildingTag(type, tag.tagId);
                    },
                    label: Text(tag.tagName),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _ExistingBuildingDraftForm extends StatelessWidget {
  const _ExistingBuildingDraftForm({required this.controller});

  final RecordDraftController controller;

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
          _SelectedExistingBuildingCard(building: selectedBuilding),
        ],
        const SizedBox(height: 16),
        const _NextStageNotice(),
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
  const _SelectedExistingBuildingCard({required this.building});

  final Building building;

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
              Expanded(child: Text('既存建物のタグはこの画面では変更できません。')),
            ],
          ),
          const SizedBox(height: 12),
          _ReadOnlyTagGroup(label: '設計タグ', values: building.designTags),
          const SizedBox(height: 10),
          _ReadOnlyTagGroup(label: '営業タグ', values: building.salesTags),
          const SizedBox(height: 10),
          _ReadOnlyTagGroup(label: '施工タグ', values: building.constructionTags),
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

class _NextStageNotice extends StatelessWidget {
  const _NextStageNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(child: Text('きっかけタグ・感想・位置情報は次の段階で追加します。')),
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
