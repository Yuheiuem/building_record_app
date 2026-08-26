part of '../record_page.dart';

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
    final List<Building> visibleBuildings = filteredBuildings
        .take(20)
        .toList(growable: false);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                ),
                child: ListView.separated(
                  key: const Key('existing-building-results-scroll'),
                  primary: false,
                  shrinkWrap: true,
                  itemCount: visibleBuildings.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final Building building = visibleBuildings[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: Key(
                          'existing-building-option-${building.buildingId}',
                        ),
                        selected:
                            selectedBuilding?.buildingId == building.buildingId,
                        onTap: () {
                          controller.selectExistingBuilding(
                            building.buildingId,
                          );
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
                    );
                  },
                ),
              ),
              if (filteredBuildings.length > 20) ...<Widget>[
                const SizedBox(height: 8),
                const Text('先頭20件を表示しています。検索文字を追加してください。'),
              ],
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
