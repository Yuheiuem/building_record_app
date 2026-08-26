import 'dart:async';
import 'dart:math' as math;

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

part 'building/existing_building_draft_form.dart';
part 'building/new_building_draft_form.dart';
part 'building/record_building_section.dart';
part 'photo/record_photo_section.dart';
part 'save/record_save_section.dart';
part 'save/record_upload_performance.dart';
part 'shared/record_common_widgets.dart';
part 'shared/record_formatters.dart';
part 'tag/record_tag_widgets.dart';
part 'visit/record_visit_section.dart';

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
                                statusMessage:
                                    _controller.photoPreparationStatusMessage,
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
