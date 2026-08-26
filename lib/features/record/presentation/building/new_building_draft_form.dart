part of '../record_page.dart';

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
