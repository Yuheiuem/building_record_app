import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/bootstrap_data.dart';
import '../../../data/models/building.dart';
import '../../../data/models/building_detail_data.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/building_cover_photo_api_service.dart';
import '../../../data/services/building_detail_api_service.dart';
import '../../../data/services/building_information_api_service.dart';
import '../../../data/services/building_location_api_service.dart';
import '../../../data/services/photo_lifecycle_api_service.dart';
import '../../../data/services/visit_information_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../record/presentation/map_location_picker_page.dart';

class BuildingDetailPage extends StatefulWidget {
  const BuildingDetailPage({
    required this.authService,
    required this.buildingId,
    this.buildingDetailApiService,
    this.buildingCoverPhotoApiService,
    this.buildingLocationApiService,
    this.bootstrapApiService,
    this.buildingInformationApiService,
    this.visitInformationApiService,
    this.photoLifecycleApiService,
    this.enableNetworkTiles = true,
    super.key,
  });

  final AuthService authService;
  final String buildingId;
  final BuildingDetailApiService? buildingDetailApiService;
  final BuildingCoverPhotoApiService? buildingCoverPhotoApiService;
  final BuildingLocationApiService? buildingLocationApiService;
  final BootstrapApiService? bootstrapApiService;
  final BuildingInformationApiService? buildingInformationApiService;
  final VisitInformationApiService? visitInformationApiService;
  final PhotoLifecycleApiService? photoLifecycleApiService;
  final bool enableNetworkTiles;

  @override
  State<BuildingDetailPage> createState() => _BuildingDetailPageState();
}

class _BuildingDetailPageState extends State<BuildingDetailPage> {
  static const int _initialPhotoLimit = 4;

  late final BuildingDetailApiService _apiService;
  late final bool _ownsApiService;
  late final BuildingCoverPhotoApiService _coverPhotoApiService;
  late final bool _ownsCoverPhotoApiService;
  late final BuildingLocationApiService _locationApiService;
  late final bool _ownsLocationApiService;
  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;
  late final BuildingInformationApiService _informationApiService;
  late final bool _ownsInformationApiService;
  late final VisitInformationApiService _visitInformationApiService;
  late final bool _ownsVisitInformationApiService;
  late final PhotoLifecycleApiService _photoLifecycleApiService;
  late final bool _ownsPhotoLifecycleApiService;

  final Map<String, Future<BuildingPhotoData>> _thumbnailFutures =
      <String, Future<BuildingPhotoData>>{};
  final Map<String, Future<BuildingPhotoData>> _fullPhotoFutures =
      <String, Future<BuildingPhotoData>>{};
  final _AsyncRequestLimiter _thumbnailRequestLimiter = _AsyncRequestLimiter(
    maxConcurrent: 4,
  );

  BuildingDetailData? _detail;
  String? _errorMessage;
  bool _isLoading = false;
  int _visiblePhotoLimit = _initialPhotoLimit;

  @override
  void initState() {
    super.initState();
    _ownsApiService = widget.buildingDetailApiService == null;
    _apiService =
        widget.buildingDetailApiService ?? HttpBuildingDetailApiService();
    _ownsCoverPhotoApiService = widget.buildingCoverPhotoApiService == null;
    _coverPhotoApiService =
        widget.buildingCoverPhotoApiService ??
        HttpBuildingCoverPhotoApiService();
    _ownsLocationApiService = widget.buildingLocationApiService == null;
    _locationApiService =
        widget.buildingLocationApiService ?? HttpBuildingLocationApiService();
    _ownsBootstrapApiService = widget.bootstrapApiService == null;
    _bootstrapApiService =
        widget.bootstrapApiService ?? HttpBootstrapApiService();
    _ownsInformationApiService = widget.buildingInformationApiService == null;
    _informationApiService =
        widget.buildingInformationApiService ??
        HttpBuildingInformationApiService();
    _ownsVisitInformationApiService = widget.visitInformationApiService == null;
    _visitInformationApiService =
        widget.visitInformationApiService ?? HttpVisitInformationApiService();
    _ownsPhotoLifecycleApiService = widget.photoLifecycleApiService == null;
    _photoLifecycleApiService =
        widget.photoLifecycleApiService ?? HttpPhotoLifecycleApiService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
    });
  }

  @override
  void didUpdateWidget(BuildingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId) {
      _thumbnailFutures.clear();
      _fullPhotoFutures.clear();
      _visiblePhotoLimit = _initialPhotoLimit;
      _detail = null;
      _errorMessage = null;
      _isLoading = false;
      unawaited(_loadDetail());
    }
  }

  @override
  void dispose() {
    if (_ownsApiService) {
      _apiService.close();
    }
    if (_ownsCoverPhotoApiService) {
      _coverPhotoApiService.close();
    }
    if (_ownsLocationApiService) {
      _locationApiService.close();
    }
    if (_ownsBootstrapApiService) {
      _bootstrapApiService.close();
    }
    if (_ownsInformationApiService) {
      _informationApiService.close();
    }
    if (_ownsVisitInformationApiService) {
      _visitInformationApiService.close();
    }
    if (_ownsPhotoLifecycleApiService) {
      _photoLifecycleApiService.close();
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (_isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final BuildingDetailData result = await _apiService.getBuildingDetail(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: widget.buildingId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = result;
        _thumbnailFutures.clear();
        _fullPhotoFutures.clear();
        _visiblePhotoLimit = _initialPhotoLimit;
        _isLoading = false;
      });
    } on BuildingDetailApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '建物詳細を取得できませんでした。もう一度送信してください。';
      });
    }
  }

  Future<BuildingPhotoData> _thumbnailFuture(BuildingPhoto photo) {
    return _thumbnailFutures.putIfAbsent(photo.photoId, () {
      final String? idToken = widget.authService.idToken;
      if (idToken == null || idToken.isEmpty) {
        return Future<BuildingPhotoData>.error(
          const BuildingDetailApiException('Googleログイン情報を取得できませんでした。'),
        );
      }

      return _thumbnailRequestLimiter.schedule<BuildingPhotoData>(() {
        return _apiService.getPhotoThumbnailData(
          requestId: const Uuid().v4(),
          clientVersion: AppConfig.version,
          idToken: idToken,
          photoId: photo.photoId,
        );
      });
    });
  }

  Future<BuildingPhotoData> _fullPhotoFuture(BuildingPhoto photo) {
    return _fullPhotoFutures.putIfAbsent(photo.photoId, () {
      final String? idToken = widget.authService.idToken;
      if (idToken == null || idToken.isEmpty) {
        return Future<BuildingPhotoData>.error(
          const BuildingDetailApiException('Googleログイン情報を取得できませんでした。'),
        );
      }

      return _apiService.getPhotoData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        photoId: photo.photoId,
      );
    });
  }

  void _retryThumbnail(BuildingPhoto photo) {
    setState(() {
      _thumbnailFutures.remove(photo.photoId);
    });
  }

  void _retryFullPhoto(BuildingPhoto photo) {
    _fullPhotoFutures.remove(photo.photoId);
  }

  void _openPhoto(BuildingPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _FullPhotoDialog(
          photo: photo,
          loadPhoto: () => _fullPhotoFuture(photo),
          onRetry: () => _retryFullPhoto(photo),
        );
      },
    );
  }

  Future<void> _openDriveFolder(String folderId) async {
    final Uri folderUri = Uri.https(
      'drive.google.com',
      '/drive/folders/$folderId',
    );

    try {
      final bool launched = await launchUrl(
        folderUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google Driveを開けませんでした。')));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google Driveを開けませんでした。')));
    }
  }

  Future<void> _addPhotosToVisit(BuildingVisit visit) async {
    final bool? changed = await context.push<bool>(
      AppRoutes.addPhotosToVisit(widget.buildingId, visit.visitId),
    );

    if (!mounted || changed != true) {
      return;
    }

    await _loadDetail();
  }

  Future<void> _editBuildingInformation() async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    late final BootstrapData bootstrapData;
    try {
      bootstrapData = await _bootstrapApiService.getBootstrapData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );
    } on BootstrapApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'タグ一覧を取得できませんでした。もう一度送信してください。';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });

    final Map<String, BuildingTag> editTagsById = <String, BuildingTag>{
      for (final BuildingTag tag in detail.tags) tag.tagId: tag,
      for (final BuildingTag tag in bootstrapData.tags) tag.tagId: tag,
    };
    final _BuildingInformationEditResult? result =
        await showDialog<_BuildingInformationEditResult>(
          context: context,
          builder: (BuildContext dialogContext) {
            return _BuildingInformationEditDialog(
              building: detail.building,
              tags: editTagsById.values.toList(growable: false),
            );
          },
        );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _informationApiService.updateBuildingInformation(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        buildingName: result.buildingName,
        address: result.address,
        designTagIds: result.designTagIds,
        salesTagIds: result.salesTagIds,
        constructionTagIds: result.constructionTagIds,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('建物情報を更新しました。')));
    } on BuildingInformationApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '建物情報を更新できませんでした。もう一度送信してください。';
      });
    }
  }

  Future<void> _editVisitInformation(BuildingVisit visit) async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    late final BootstrapData bootstrapData;
    try {
      bootstrapData = await _bootstrapApiService.getBootstrapData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );
    } on BootstrapApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'タグ一覧を取得できませんでした。もう一度送信してください。';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });

    final Map<String, BuildingTag> editTagsById = <String, BuildingTag>{
      for (final BuildingTag tag in detail.tags) tag.tagId: tag,
      for (final BuildingTag tag in bootstrapData.tags) tag.tagId: tag,
    };
    final _VisitInformationEditResult? result =
        await showDialog<_VisitInformationEditResult>(
          context: context,
          builder: (BuildContext dialogContext) {
            return _VisitInformationEditDialog(
              visit: visit,
              building: detail.building,
              tags: editTagsById.values.toList(growable: false),
              enableNetworkTiles: widget.enableNetworkTiles,
            );
          },
        );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _visitInformationApiService.updateVisitInformation(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        visitId: visit.visitId,
        visitedAt: result.visitedAt,
        triggerTagIds: result.triggerTagIds,
        impression: result.impression,
        latitude: result.latitude,
        longitude: result.longitude,
        accuracyM: result.accuracyM,
        locationSource: result.locationSource,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訪問記録を更新しました。')));
    } on VisitInformationApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '訪問記録を更新できませんでした。もう一度送信してください。';
      });
    }
  }

  Future<void> _setCoverPhoto(BuildingPhoto photo) async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }
    if (detail.building.coverPhotoId == photo.photoId) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _coverPhotoApiService.updateBuildingCoverPhoto(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        photoId: photo.photoId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('代表写真を更新しました。')));
    } on BuildingCoverPhotoApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '代表写真を更新できませんでした。もう一度送信してください。';
      });
    }
  }

  Future<void> _hidePhoto(BuildingPhoto photo) async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final bool confirmed = await _confirmHidePhoto(context, photo);
    if (!mounted || !confirmed) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _photoLifecycleApiService.hidePhoto(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        photoId: photo.photoId,
      );

      if (!mounted) {
        return;
      }
      _thumbnailFutures.remove(photo.photoId);
      _fullPhotoFutures.remove(photo.photoId);
      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真を非表示にしました。')));
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '写真を非表示にできませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deletePhotoPermanently(BuildingPhoto photo) async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final bool confirmed = await _confirmPermanentPhotoDeletion(
      context,
      photo,
    );
    if (!mounted || !confirmed) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _photoLifecycleApiService.deletePhotoPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        photoId: photo.photoId,
      );

      if (!mounted) {
        return;
      }
      _thumbnailFutures.remove(photo.photoId);
      _fullPhotoFutures.remove(photo.photoId);
      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真をGoogle Driveから完全に削除しました。')),
      );
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '写真を完全削除できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _openHiddenPhotoManager() async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _HiddenPhotoManagerDialog(
          apiService: _photoLifecycleApiService,
          buildingId: detail.building.buildingId,
          idToken: idToken,
        );
      },
    );

    if (!mounted || changed != true) {
      return;
    }

    _thumbnailFutures.clear();
    _fullPhotoFutures.clear();
    await _loadDetail();
  }

  Future<void> _editBuildingLocation() async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final Building building = detail.building;
    final RecordDraftLocation? selectedLocation = await Navigator.of(context)
        .push<RecordDraftLocation>(
          MaterialPageRoute<RecordDraftLocation>(
            builder: (BuildContext context) {
              return MapLocationPickerPage(
                initialLatitude: building.latitude,
                initialLongitude: building.longitude,
                enableNetworkTiles: widget.enableNetworkTiles,
              );
            },
          ),
        );

    if (!mounted || selectedLocation == null) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _locationApiService.updateBuildingLocation(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: building.buildingId,
        latitude: selectedLocation.latitude,
        longitude: selectedLocation.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      await _loadDetail();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('建物の代表位置を更新しました。')));
    } on BuildingLocationApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '代表位置を更新できませんでした。もう一度送信してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '建物詳細',
        showVersion: true,
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final BuildingDetailData? detail = _detail;

    if (detail == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detail == null) {
      return _DetailErrorState(
        message: _errorMessage ?? '建物詳細を取得できませんでした。',
        onRetry: _loadDetail,
      );
    }

    final Map<String, BuildingTag> tagsById = <String, BuildingTag>{
      for (final BuildingTag tag in detail.tags) tag.tagId: tag,
    };
    final int shownPhotoCount = detail.photos.length < _visiblePhotoLimit
        ? detail.photos.length
        : _visiblePhotoLimit;
    final List<BuildingPhoto> shownPhotos = detail.photos
        .take(shownPhotoCount)
        .toList(growable: false);

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _BuildingOverviewSection(
                    detail: detail,
                    tagsById: tagsById,
                    enableNetworkTiles: widget.enableNetworkTiles,
                    onRefresh: _loadDetail,
                    onEditInformation: _editBuildingInformation,
                    onEditLocation: _editBuildingLocation,
                    onRecordRevisit: () {
                      unawaited(
                        context.push<void>(
                          AppRoutes.recordForBuilding(
                            detail.building.buildingId,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineErrorMessage(message: _errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  _PhotoGallerySection(
                    allPhotoCount: detail.photos.length,
                    photos: shownPhotos,
                    coverPhotoId: detail.building.coverPhotoId,
                    thumbnailFuture: _thumbnailFuture,
                    onRetryThumbnail: _retryThumbnail,
                    onOpenPhoto: _openPhoto,
                    onSetCoverPhoto: _setCoverPhoto,
                    onHidePhoto: _hidePhoto,
                    onDeletePhotoPermanently: _deletePhotoPermanently,
                    onManageHiddenPhotos: _openHiddenPhotoManager,
                    onShowMore: shownPhotoCount < detail.photos.length
                        ? () {
                            setState(() {
                              _visiblePhotoLimit = detail.photos.length;
                            });
                          }
                        : null,
                    onOpenDrive: detail.building.driveFolderId == null
                        ? null
                        : () {
                            unawaited(
                              _openDriveFolder(detail.building.driveFolderId!),
                            );
                          },
                  ),
                  const SizedBox(height: 12),
                  _VisitHistorySection(
                    detail: detail,
                    tagsById: tagsById,
                    onEditVisit: _editVisitInformation,
                    onAddPhotos: _addPhotosToVisit,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _BuildingOverviewSection extends StatelessWidget {
  const _BuildingOverviewSection({
    required this.detail,
    required this.tagsById,
    required this.enableNetworkTiles,
    required this.onRefresh,
    required this.onEditInformation,
    required this.onEditLocation,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final bool enableNetworkTiles;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditInformation;
  final VoidCallback onEditLocation;
  final VoidCallback onRecordRevisit;

  @override
  Widget build(BuildContext context) {
    final Building building = detail.building;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideLayout = constraints.maxWidth >= 900;
        final Widget information = _BuildingInformationCard(
          detail: detail,
          tagsById: tagsById,
          onRefresh: onRefresh,
          onEditInformation: onEditInformation,
          onEditLocation: onEditLocation,
          onRecordRevisit: onRecordRevisit,
        );
        final Widget map = _BuildingLocationCard(
          building: building,
          enableNetworkTiles: enableNetworkTiles,
        );

        if (wideLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: information),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: SizedBox(height: 420, child: map)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            information,
            const SizedBox(height: 12),
            SizedBox(height: 320, child: map),
          ],
        );
      },
    );
  }
}

class _BuildingInformationCard extends StatelessWidget {
  const _BuildingInformationCard({
    required this.detail,
    required this.tagsById,
    required this.onRefresh,
    required this.onEditInformation,
    required this.onEditLocation,
    required this.onRecordRevisit,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditInformation;
  final VoidCallback onEditLocation;
  final VoidCallback onRecordRevisit;

  @override
  Widget build(BuildContext context) {
    final Building building = detail.building;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.apartment_outlined,
                  size: 34,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        building.buildingName,
                        key: const Key('building-detail-name'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (building.address != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          building.address!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('refresh-building-detail'),
                  tooltip: '最新データを取得',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _CountChip(
                  icon: Icons.event_note,
                  label: '訪問 ${detail.counts.visits}件',
                ),
                _CountChip(
                  icon: Icons.photo_library,
                  label: '写真 ${detail.counts.photos}枚',
                ),
                if (building.latitude != null && building.longitude != null)
                  _CountChip(
                    key: const Key('building-representative-location-chip'),
                    icon: Icons.location_on_outlined,
                    label: '代表位置あり',
                    onPressed: onEditLocation,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _TagGroup(
              title: '設計',
              tagIds: building.designTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 10),
            _TagGroup(
              title: '営業',
              tagIds: building.salesTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 10),
            _TagGroup(
              title: '施工',
              tagIds: building.constructionTags,
              tagsById: tagsById,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const Key('edit-building-information'),
              onPressed: onEditInformation,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('建物情報を編集'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('record-building-revisit'),
              onPressed: onRecordRevisit,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('再訪を記録'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Icon(icon, size: 18);
    if (onPressed != null) {
      return ActionChip(
        avatar: avatar,
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );
    }
    return Chip(
      avatar: avatar,
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.tagIds,
    required this.tagsById,
  });

  final String title;
  final List<String> tagIds;
  final Map<String, BuildingTag> tagsById;

  @override
  Widget build(BuildContext context) {
    final List<String> names = tagIds
        .map((String id) => tagsById[id]?.tagName ?? '未登録タグ')
        .toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Expanded(
          child: names.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    '未登録',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: names
                      .map(
                        (String name) => Chip(
                          label: Text(name),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

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

class _BuildingLocationCard extends StatelessWidget {
  const _BuildingLocationCard({
    required this.building,
    required this.enableNetworkTiles,
  });

  final Building building;
  final bool enableNetworkTiles;

  @override
  Widget build(BuildContext context) {
    final double? latitude = building.latitude;
    final double? longitude = building.longitude;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                const Icon(Icons.map_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '代表位置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: latitude == null || longitude == null
                ? const Center(child: Text('代表位置は登録されていません。'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: 17,
                      minZoom: 5,
                      maxZoom: 19,
                    ),
                    children: <Widget>[
                      if (enableNetworkTiles)
                        TileLayer(
                          urlTemplate:
                              'https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png',
                          maxNativeZoom: 18,
                          userAgentPackageName: 'building_record_app',
                        ),
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 46,
                            height: 46,
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 42,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SimpleAttributionWidget(source: Text('国土地理院')),
                    ],
                  ),
          ),
          if (latitude != null && longitude != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Text(
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoGallerySection extends StatelessWidget {
  const _PhotoGallerySection({
    required this.allPhotoCount,
    required this.photos,
    required this.coverPhotoId,
    required this.thumbnailFuture,
    required this.onRetryThumbnail,
    required this.onOpenPhoto,
    required this.onSetCoverPhoto,
    required this.onHidePhoto,
    required this.onDeletePhotoPermanently,
    required this.onManageHiddenPhotos,
    required this.onShowMore,
    required this.onOpenDrive,
  });

  final int allPhotoCount;
  final List<BuildingPhoto> photos;
  final String? coverPhotoId;
  final Future<BuildingPhotoData> Function(BuildingPhoto photo) thumbnailFuture;
  final ValueChanged<BuildingPhoto> onRetryThumbnail;
  final ValueChanged<BuildingPhoto> onOpenPhoto;
  final ValueChanged<BuildingPhoto> onSetCoverPhoto;
  final ValueChanged<BuildingPhoto> onHidePhoto;
  final ValueChanged<BuildingPhoto> onDeletePhotoPermanently;
  final VoidCallback onManageHiddenPhotos;
  final VoidCallback? onShowMore;
  final VoidCallback? onOpenDrive;

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
                Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '写真ギャラリー',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$allPhotoCount枚'),
              ],
            ),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              const _SectionEmptyState(
                icon: Icons.photo,
                message: 'この建物の写真はまだありません。',
              )
            else
              GridView.builder(
                key: const Key('building-photo-gallery'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.18,
                ),
                itemCount: photos.length,
                itemBuilder: (BuildContext context, int index) {
                  final BuildingPhoto photo = photos[index];
                  return _AuthenticatedPhotoTile(
                    key: ValueKey<String>('building-photo-${photo.photoId}'),
                    photo: photo,
                    thumbnailFuture: thumbnailFuture(photo),
                    isCoverPhoto: coverPhotoId == photo.photoId,
                    onRetry: () => onRetryThumbnail(photo),
                    onOpen: () => onOpenPhoto(photo),
                    onSetCoverPhoto: () => onSetCoverPhoto(photo),
                    onHidePhoto: () => onHidePhoto(photo),
                    onDeletePermanently: () =>
                        onDeletePhotoPermanently(photo),
                  );
                },
              ),
            if (onShowMore != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('show-all-building-photos'),
                onPressed: onShowMore,
                icon: const Icon(Icons.expand_more),
                label: Text('すべて表示（残り${allPhotoCount - photos.length}枚）'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('manage-hidden-building-photos'),
              onPressed: onManageHiddenPhotos,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('非表示写真を管理'),
            ),
            if (onOpenDrive != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-building-drive-folder'),
                onPressed: onOpenDrive,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Google Driveで写真フォルダを開く'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PhotoTileAction { hide, deletePermanently }

class _AuthenticatedPhotoTile extends StatelessWidget {
  const _AuthenticatedPhotoTile({
    required this.photo,
    required this.thumbnailFuture,
    required this.isCoverPhoto,
    required this.onRetry,
    required this.onOpen,
    required this.onSetCoverPhoto,
    required this.onHidePhoto,
    required this.onDeletePermanently,
    super.key,
  });

  final BuildingPhoto photo;
  final Future<BuildingPhotoData> thumbnailFuture;
  final bool isCoverPhoto;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final VoidCallback onSetCoverPhoto;
  final VoidCallback onHidePhoto;
  final VoidCallback onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BuildingPhotoData>(
      future: thumbnailFuture,
      builder:
          (BuildContext context, AsyncSnapshot<BuildingPhotoData> snapshot) {
            if (snapshot.hasData) {
              final BuildingPhotoData data = snapshot.data!;
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: InkWell(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: Image.memory(
                          data.bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Center(
                                  child: Icon(Icons.broken_image, size: 42),
                                );
                              },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _formatDateTime(
                                  photo.takenAt ?? photo.createdAt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              key: ValueKey<String>(
                                'set-cover-photo-${photo.photoId}',
                              ),
                              tooltip: isCoverPhoto ? '代表写真に設定済み' : '代表写真に設定',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 34,
                                height: 34,
                              ),
                              onPressed: isCoverPhoto ? null : onSetCoverPhoto,
                              icon: Icon(
                                isCoverPhoto ? Icons.star : Icons.star_border,
                                color: isCoverPhoto
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 2),
                            PopupMenuButton<_PhotoTileAction>(
                              key: ValueKey<String>(
                                'photo-actions-${photo.photoId}',
                              ),
                              tooltip: '写真の操作',
                              padding: EdgeInsets.zero,
                              onSelected: (_PhotoTileAction action) {
                                switch (action) {
                                  case _PhotoTileAction.hide:
                                    onHidePhoto();
                                    return;
                                  case _PhotoTileAction.deletePermanently:
                                    onDeletePermanently();
                                    return;
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                final Color errorColor = Theme.of(
                                  context,
                                ).colorScheme.error;
                                return <PopupMenuEntry<_PhotoTileAction>>[
                                  PopupMenuItem<_PhotoTileAction>(
                                    key: ValueKey<String>(
                                      'hide-photo-${photo.photoId}',
                                    ),
                                    value: _PhotoTileAction.hide,
                                    child: const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.visibility_off_outlined,
                                      ),
                                      title: Text('非表示にする'),
                                    ),
                                  ),
                                  PopupMenuItem<_PhotoTileAction>(
                                    key: ValueKey<String>(
                                      'delete-photo-permanently-${photo.photoId}',
                                    ),
                                    value: _PhotoTileAction.deletePermanently,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.delete_forever_outlined,
                                        color: errorColor,
                                      ),
                                      title: Text(
                                        '完全に削除',
                                        style: TextStyle(color: errorColor),
                                      ),
                                    ),
                                  ),
                                ];
                              },
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.zoom_in, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.broken_image, size: 36),
                      const SizedBox(height: 8),
                      const Text('写真を取得できませんでした。'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          },
    );
  }
}

class _FullPhotoDialog extends StatefulWidget {
  const _FullPhotoDialog({
    required this.photo,
    required this.loadPhoto,
    required this.onRetry,
  });

  final BuildingPhoto photo;
  final Future<BuildingPhotoData> Function() loadPhoto;
  final VoidCallback onRetry;

  @override
  State<_FullPhotoDialog> createState() => _FullPhotoDialogState();
}

class _FullPhotoDialogState extends State<_FullPhotoDialog> {
  late Future<BuildingPhotoData> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = widget.loadPhoto();
  }

  void _retry() {
    widget.onRetry();
    setState(() {
      _photoFuture = widget.loadPhoto();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('写真'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
          ),
        ),
        body: FutureBuilder<BuildingPhotoData>(
          future: _photoFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<BuildingPhotoData> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.broken_image, size: 52),
                          const SizedBox(height: 12),
                          const Text('元の写真を取得できませんでした。'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final BuildingPhotoData data = snapshot.data!;
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Image.memory(
                              data.bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Text(
                            _formatDateTime(
                              widget.photo.takenAt ?? widget.photo.createdAt,
                            ),
                          ),
                          Text(_formatBytes(widget.photo.byteSize)),
                          if (widget.photo.width != null &&
                              widget.photo.height != null)
                            Text(
                              '${widget.photo.width} × ${widget.photo.height}',
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

Future<bool> _confirmHidePhoto(
  BuildContext context,
  BuildingPhoto photo,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('写真を非表示にしますか？'),
        content: Text(
          '${photo.fileName}\n\n'
          '通常の写真ギャラリーから隠します。Google Drive上の元画像とサムネイルは残るため、あとで復元できます。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-hide-photo'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('非表示にする'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> _confirmPermanentPhotoDeletion(
  BuildContext context,
  BuildingPhoto photo,
) async {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(
          '写真を完全に削除しますか？',
          style: TextStyle(color: colorScheme.error),
        ),
        content: Text(
          '${photo.fileName}\n\n'
          'Google Drive上の元画像とサムネイルを完全に削除します。容量は解放されますが、この操作はアプリから元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-permanent-photo-deletion'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('完全に削除'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _HiddenPhotoManagerDialog extends StatefulWidget {
  const _HiddenPhotoManagerDialog({
    required this.apiService,
    required this.buildingId,
    required this.idToken,
  });

  final PhotoLifecycleApiService apiService;
  final String buildingId;
  final String idToken;

  @override
  State<_HiddenPhotoManagerDialog> createState() =>
      _HiddenPhotoManagerDialogState();
}

class _HiddenPhotoManagerDialogState extends State<_HiddenPhotoManagerDialog> {
  final List<BuildingPhoto> _photos = <BuildingPhoto>[];
  bool _isLoading = false;
  bool _isMutating = false;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<BuildingPhoto> photos = await widget.apiService
          .getHiddenBuildingPhotos(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: widget.idToken,
            buildingId: widget.buildingId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos
          ..clear()
          ..addAll(photos);
        _isLoading = false;
      });
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '非表示写真を取得できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _preview(BuildingPhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _HiddenPhotoPreviewDialog(
          apiService: widget.apiService,
          idToken: widget.idToken,
          photo: photo,
        );
      },
    );
  }

  Future<void> _restore(BuildingPhoto photo) async {
    if (_isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.restorePhoto(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        photoId: photo.photoId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos.removeWhere(
          (BuildingPhoto item) => item.photoId == photo.photoId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写真を復元しました。')));
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = '写真を復元できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deletePermanently(BuildingPhoto photo) async {
    if (_isMutating) {
      return;
    }
    final bool confirmed = await _confirmPermanentPhotoDeletion(
      context,
      photo,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await widget.apiService.deletePhotoPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        photoId: photo.photoId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos.removeWhere(
          (BuildingPhoto item) => item.photoId == photo.photoId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真をGoogle Driveから完全に削除しました。')),
      );
    } on PhotoLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMutating = false;
        _errorMessage = '写真を完全削除できませんでした。もう一度お試しください。';
      });
    }
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非表示写真を管理'),
          leading: IconButton(
            key: const Key('close-hidden-photo-manager'),
            onPressed: _isMutating ? null : _close,
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            IconButton(
              key: const Key('refresh-hidden-photos'),
              onPressed: _isLoading || _isMutating ? null : _load,
              tooltip: '再取得',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '非表示写真はDrive上に残っているため復元できます。'
                              '「完全に削除」を選ぶと元画像とサムネイルを削除し、復元できなくなります。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineErrorMessage(message: _errorMessage!),
                  ],
                  const SizedBox(height: 12),
                  if (_isLoading && _photos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_photos.isEmpty)
                    const _SectionEmptyState(
                      icon: Icons.visibility_outlined,
                      message: '非表示の写真はありません。',
                    )
                  else
                    ..._photos.map((BuildingPhoto photo) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          key: ValueKey<String>(
                            'hidden-photo-${photo.photoId}',
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  photo.fileName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    Text(
                                      _formatDateTime(
                                        photo.takenAt ?? photo.createdAt,
                                      ),
                                    ),
                                    Text(_formatBytes(photo.byteSize)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      key: ValueKey<String>(
                                        'preview-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _preview(photo),
                                      icon: const Icon(Icons.image_outlined),
                                      label: const Text('確認'),
                                    ),
                                    FilledButton.tonalIcon(
                                      key: ValueKey<String>(
                                        'restore-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _restore(photo),
                                      icon: const Icon(Icons.restore),
                                      label: const Text('復元'),
                                    ),
                                    TextButton.icon(
                                      key: ValueKey<String>(
                                        'delete-hidden-photo-${photo.photoId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _deletePermanently(photo),
                                      icon: Icon(
                                        Icons.delete_forever_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      label: Text(
                                        '完全に削除',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              if (_isMutating)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HiddenPhotoPreviewDialog extends StatefulWidget {
  const _HiddenPhotoPreviewDialog({
    required this.apiService,
    required this.idToken,
    required this.photo,
  });

  final PhotoLifecycleApiService apiService;
  final String idToken;
  final BuildingPhoto photo;

  @override
  State<_HiddenPhotoPreviewDialog> createState() =>
      _HiddenPhotoPreviewDialogState();
}

class _HiddenPhotoPreviewDialogState extends State<_HiddenPhotoPreviewDialog> {
  late Future<BuildingPhotoData> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _load();
  }

  Future<BuildingPhotoData> _load() {
    return widget.apiService.getHiddenPhotoThumbnailData(
      requestId: const Uuid().v4(),
      clientVersion: AppConfig.version,
      idToken: widget.idToken,
      photoId: widget.photo.photoId,
    );
  }

  void _retry() {
    setState(() {
      _photoFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非表示写真を確認'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
          ),
        ),
        body: FutureBuilder<BuildingPhotoData>(
          future: _photoFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<BuildingPhotoData> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.broken_image, size: 52),
                          const SizedBox(height: 12),
                          const Text('非表示写真を取得できませんでした。'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final BuildingPhotoData data = snapshot.data!;
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Image.memory(data.bytes, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Text(widget.photo.fileName),
                          Text(
                            _formatDateTime(
                              widget.photo.takenAt ?? widget.photo.createdAt,
                            ),
                          ),
                          Text(_formatBytes(widget.photo.byteSize)),
                        ],
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

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

class _VisitHistorySection extends StatelessWidget {
  const _VisitHistorySection({
    required this.detail,
    required this.tagsById,
    required this.onEditVisit,
    required this.onAddPhotos,
  });

  final BuildingDetailData detail;
  final Map<String, BuildingTag> tagsById;
  final ValueChanged<BuildingVisit> onEditVisit;
  final ValueChanged<BuildingVisit> onAddPhotos;

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
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '訪問履歴',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${detail.visits.length}件'),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.visits.isEmpty)
              const _SectionEmptyState(
                icon: Icons.event_busy,
                message: '完了した訪問記録はまだありません。',
              )
            else
              ListView.separated(
                key: const Key('building-visit-history'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: detail.visits.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final BuildingVisit visit = detail.visits[index];
                  return _VisitCard(
                    visit: visit,
                    photoCount: detail.photosForVisit(visit.visitId).length,
                    tagsById: tagsById,
                    onEdit: () => onEditVisit(visit),
                    onAddPhotos: () => onAddPhotos(visit),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.photoCount,
    required this.tagsById,
    required this.onEdit,
    required this.onAddPhotos,
  });

  final BuildingVisit visit;
  final int photoCount;
  final Map<String, BuildingTag> tagsById;
  final VoidCallback onEdit;
  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<String> triggerNames = visit.triggerTags
        .map((String id) => tagsById[id]?.tagName ?? '未登録タグ')
        .toList(growable: false);

    return Container(
      key: ValueKey<String>('building-visit-${visit.visitId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTime(visit.visitedAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                avatar: const Icon(Icons.photo, size: 17),
                label: Text('$photoCount枚'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (triggerNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: triggerNames
                  .map(
                    (String name) => Chip(
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (visit.impression.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(visit.impression),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              if (visit.latitude != null && visit.longitude != null)
                _MetadataText(
                  icon: Icons.location_on_outlined,
                  text:
                      '${visit.latitude!.toStringAsFixed(6)}, ${visit.longitude!.toStringAsFixed(6)}',
                ),
              if (visit.accuracyM != null)
                _MetadataText(
                  icon: Icons.gps_fixed,
                  text: '精度 ${visit.accuracyM!.toStringAsFixed(1)}m',
                ),
              if (visit.locationSource.isNotEmpty)
                _MetadataText(
                  icon: Icons.my_location,
                  text: _locationSourceLabel(visit.locationSource),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: ValueKey<String>('edit-visit-${visit.visitId}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('訪問記録を編集'),
              ),
              OutlinedButton.icon(
                key: ValueKey<String>('add-photos-to-visit-${visit.visitId}'),
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('写真を追加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetadataText extends StatelessWidget {
  const _MetadataText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度取得'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _AsyncRequestLimiter {
  _AsyncRequestLimiter({required this.maxConcurrent})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;
  final Queue<Future<void> Function()> _queue =
      Queue<Future<void> Function()>();
  int _activeCount = 0;

  Future<T> schedule<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _queue.add(() async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final Future<void> Function() task = _queue.removeFirst();
      _activeCount += 1;
      unawaited(
        task().whenComplete(() {
          _activeCount -= 1;
          _drain();
        }),
      );
    }
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '日時不明';
  }
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _locationSourceLabel(String source) {
  return switch (source) {
    'gps' => 'GPS',
    'manual' => '手動指定',
    'building_fallback' => '建物代表位置',
    'test' => 'テスト位置',
    _ => source,
  };
}
