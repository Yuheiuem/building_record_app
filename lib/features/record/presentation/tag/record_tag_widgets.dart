part of '../record_page.dart';

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
