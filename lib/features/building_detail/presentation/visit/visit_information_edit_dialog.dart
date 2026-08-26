part of '../building_detail_page.dart';

class _VisitInformationEditResult {
  const _VisitInformationEditResult({
    required this.visitedAt,
    required this.triggerTagIds,
    required this.impression,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationSource,
  });

  final DateTime visitedAt;
  final List<String> triggerTagIds;
  final String impression;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String locationSource;
}

class _VisitInformationEditDialog extends StatefulWidget {
  const _VisitInformationEditDialog({
    required this.visit,
    required this.building,
    required this.tags,
    required this.enableNetworkTiles,
  });

  final BuildingVisit visit;
  final Building building;
  final List<BuildingTag> tags;
  final bool enableNetworkTiles;

  @override
  State<_VisitInformationEditDialog> createState() =>
      _VisitInformationEditDialogState();
}

class _VisitInformationEditDialogState
    extends State<_VisitInformationEditDialog> {
  late final TextEditingController _impressionController;
  late DateTime _visitedAt;
  late final Set<String> _triggerTagIds;
  double? _latitude;
  double? _longitude;
  double? _accuracyM;
  late String _locationSource;

  @override
  void initState() {
    super.initState();
    _impressionController = TextEditingController(
      text: widget.visit.impression,
    );
    _visitedAt = widget.visit.visitedAt.toLocal();
    _triggerTagIds = widget.visit.triggerTags.toSet();
    final bool hasVisitLocation =
        widget.visit.latitude != null && widget.visit.longitude != null;
    _latitude = hasVisitLocation ? widget.visit.latitude : null;
    _longitude = hasVisitLocation ? widget.visit.longitude : null;
    _accuracyM = hasVisitLocation ? widget.visit.accuracyM : null;
    _locationSource = hasVisitLocation ? widget.visit.locationSource : '';
  }

  @override
  void dispose() {
    _impressionController.dispose();
    super.dispose();
  }

  List<BuildingTag> get _triggerTagOptions {
    final List<BuildingTag> result = widget.tags
        .where(
          (BuildingTag tag) =>
              tag.tagType == BuildingTagType.trigger &&
              (tag.isActive || _triggerTagIds.contains(tag.tagId)),
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

  Future<void> _selectVisitedAt() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _visitedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '訪問日を選択',
    );
    if (!mounted || selectedDate == null) {
      return;
    }

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitedAt),
      helpText: '訪問時刻を選択',
    );
    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      _visitedAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _selectLocation() async {
    final bool hasVisitLocation = _latitude != null && _longitude != null;
    final double? initialLatitude = hasVisitLocation
        ? _latitude
        : widget.building.latitude;
    final double? initialLongitude = hasVisitLocation
        ? _longitude
        : widget.building.longitude;
    final RecordDraftLocation? selectedLocation = await Navigator.of(context)
        .push<RecordDraftLocation>(
          MaterialPageRoute<RecordDraftLocation>(
            builder: (BuildContext context) {
              return MapLocationPickerPage(
                initialLatitude: initialLatitude,
                initialLongitude: initialLongitude,
                enableNetworkTiles: widget.enableNetworkTiles,
              );
            },
          ),
        );

    if (!mounted || selectedLocation == null) {
      return;
    }

    setState(() {
      _latitude = selectedLocation.latitude;
      _longitude = selectedLocation.longitude;
      _accuracyM = selectedLocation.accuracyM;
      _locationSource = selectedLocation.source.apiValue;
    });
  }

  void _toggleTriggerTag(String tagId, bool selected) {
    setState(() {
      if (selected) {
        _triggerTagIds.add(tagId);
      } else {
        _triggerTagIds.remove(tagId);
      }
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _VisitInformationEditResult(
        visitedAt: _visitedAt,
        triggerTagIds: _triggerTagIds.toList(growable: false),
        impression: _impressionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        accuracyM: _accuracyM,
        locationSource: _locationSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<BuildingTag> triggerOptions = _triggerTagOptions;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('訪問記録を編集'),
          leading: IconButton(
            key: const Key('cancel-visit-information-edit'),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'キャンセル',
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '訪問日時',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(_visitedAt),
                        key: const Key('edit-visit-date-time-value'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('edit-visit-date-time'),
                        onPressed: _selectVisitedAt,
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('日時を変更'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BuildingEditTagSection(
                title: 'きっかけタグ',
                options: triggerOptions,
                selectedIds: _triggerTagIds,
                keyPrefix: 'edit-visit-trigger-tag',
                onSelected: _toggleTriggerTag,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('edit-visit-impression-field'),
                controller: _impressionController,
                maxLength: 2000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '感想（任意）',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '訪問位置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_latitude != null && _longitude != null) ...<Widget>[
                        Text(
                          '${_latitude!.toStringAsFixed(6)}, '
                          '${_longitude!.toStringAsFixed(6)}',
                          key: const Key('edit-visit-location-value'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          <String>[
                            _locationSourceLabel(_locationSource),
                            if (_accuracyM != null)
                              '精度 ${_accuracyM!.toStringAsFixed(1)}m',
                          ].join('／'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else
                        Text(
                          '位置情報なし',
                          key: const Key('edit-visit-location-value'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('edit-visit-location'),
                        onPressed: _selectLocation,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('地図で位置を調整'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('save-visit-information-edit'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('変更を保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
