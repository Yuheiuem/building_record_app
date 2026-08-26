part of '../building_detail_page.dart';

class _BuildingInformationEditResult {
  const _BuildingInformationEditResult({
    required this.buildingName,
    required this.address,
    required this.designTagIds,
    required this.salesTagIds,
    required this.constructionTagIds,
  });

  final String buildingName;
  final String? address;
  final List<String> designTagIds;
  final List<String> salesTagIds;
  final List<String> constructionTagIds;
}

class _BuildingInformationEditDialog extends StatefulWidget {
  const _BuildingInformationEditDialog({
    required this.building,
    required this.tags,
  });

  final Building building;
  final List<BuildingTag> tags;

  @override
  State<_BuildingInformationEditDialog> createState() =>
      _BuildingInformationEditDialogState();
}

class _BuildingInformationEditDialogState
    extends State<_BuildingInformationEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _buildingNameController;
  late final TextEditingController _addressController;
  late final Set<String> _designTagIds;
  late final Set<String> _salesTagIds;
  late final Set<String> _constructionTagIds;

  @override
  void initState() {
    super.initState();
    _buildingNameController = TextEditingController(
      text: widget.building.buildingName,
    );
    _addressController = TextEditingController(
      text: widget.building.address ?? '',
    );
    _designTagIds = widget.building.designTags.toSet();
    _salesTagIds = widget.building.salesTags.toSet();
    _constructionTagIds = widget.building.constructionTags.toSet();
  }

  @override
  void dispose() {
    _buildingNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  List<BuildingTag> _tagOptions(BuildingTagType type, Set<String> selectedIds) {
    final List<BuildingTag> result = widget.tags
        .where(
          (BuildingTag tag) =>
              tag.tagType == type &&
              (tag.isActive || selectedIds.contains(tag.tagId)),
        )
        .toList(growable: false);
    result.sort((BuildingTag left, BuildingTag right) {
      if (left.displayOrder != right.displayOrder) {
        return left.displayOrder.compareTo(right.displayOrder);
      }
      return left.tagName.compareTo(right.tagName);
    });
    return result;
  }

  void _toggleTag(Set<String> selectedIds, String tagId, bool selected) {
    setState(() {
      if (selected) {
        selectedIds.add(tagId);
      } else {
        selectedIds.remove(tagId);
      }
    });
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final String address = _addressController.text.trim();
    Navigator.of(context).pop(
      _BuildingInformationEditResult(
        buildingName: _buildingNameController.text.trim(),
        address: address.isEmpty ? null : address,
        designTagIds: _designTagIds.toList(growable: false),
        salesTagIds: _salesTagIds.toList(growable: false),
        constructionTagIds: _constructionTagIds.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('建物情報を編集'),
          leading: IconButton(
            key: const Key('cancel-building-information-edit'),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'キャンセル',
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                TextFormField(
                  key: const Key('edit-building-name-field'),
                  controller: _buildingNameController,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '建物名',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return '建物名を入力してください。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit-building-address-field'),
                  controller: _addressController,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '住所（任意）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _BuildingEditTagSection(
                  title: '設計タグ',
                  options: _tagOptions(BuildingTagType.design, _designTagIds),
                  selectedIds: _designTagIds,
                  onSelected: (String tagId, bool selected) {
                    _toggleTag(_designTagIds, tagId, selected);
                  },
                ),
                const SizedBox(height: 12),
                _BuildingEditTagSection(
                  title: '営業タグ',
                  options: _tagOptions(BuildingTagType.sales, _salesTagIds),
                  selectedIds: _salesTagIds,
                  onSelected: (String tagId, bool selected) {
                    _toggleTag(_salesTagIds, tagId, selected);
                  },
                ),
                const SizedBox(height: 12),
                _BuildingEditTagSection(
                  title: '施工タグ',
                  options: _tagOptions(
                    BuildingTagType.construction,
                    _constructionTagIds,
                  ),
                  selectedIds: _constructionTagIds,
                  onSelected: (String tagId, bool selected) {
                    _toggleTag(_constructionTagIds, tagId, selected);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('save-building-information-edit'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('変更を保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildingEditTagSection extends StatelessWidget {
  const _BuildingEditTagSection({
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.onSelected,
    this.keyPrefix = 'edit-building-tag',
  });

  final String title;
  final List<BuildingTag> options;
  final Set<String> selectedIds;
  final void Function(String tagId, bool selected) onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (options.isEmpty)
              Text(
                '選択できるタグがありません。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options
                    .map((BuildingTag tag) {
                      return FilterChip(
                        key: ValueKey<String>('$keyPrefix-${tag.tagId}'),
                        selected: selectedIds.contains(tag.tagId),
                        onSelected: (bool selected) {
                          onSelected(tag.tagId, selected);
                        },
                        label: Text(
                          tag.isActive ? tag.tagName : '${tag.tagName}（無効）',
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
