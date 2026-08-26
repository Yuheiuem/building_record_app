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
import '../../../data/services/building_lifecycle_api_service.dart';
import '../../../data/services/building_location_api_service.dart';
import '../../../data/services/photo_lifecycle_api_service.dart';
import '../../../data/services/visit_information_api_service.dart';
import '../../../data/services/visit_lifecycle_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../record/presentation/map_location_picker_page.dart';

part 'building/building_information_card.dart';
part 'building/building_information_edit_dialog.dart';
part 'building/building_location_card.dart';
part 'building/building_overview_section.dart';
part 'photo/full_photo_dialog.dart';
part 'photo/hidden_photo_manager_dialog.dart';
part 'photo/hidden_photo_preview_dialog.dart';
part 'photo/photo_gallery_section.dart';
part 'photo/photo_tile.dart';
part 'shared/async_request_limiter.dart';
part 'shared/building_detail_common_widgets.dart';
part 'shared/building_detail_formatters.dart';
part 'visit/hidden_visit_manager_dialog.dart';
part 'visit/visit_card.dart';
part 'visit/visit_history_section.dart';
part 'visit/visit_information_edit_dialog.dart';

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
    this.visitLifecycleApiService,
    this.photoLifecycleApiService,
    this.buildingLifecycleApiService,
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
  final VisitLifecycleApiService? visitLifecycleApiService;
  final PhotoLifecycleApiService? photoLifecycleApiService;
  final BuildingLifecycleApiService? buildingLifecycleApiService;
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
  late final VisitLifecycleApiService _visitLifecycleApiService;
  late final bool _ownsVisitLifecycleApiService;
  late final PhotoLifecycleApiService _photoLifecycleApiService;
  late final bool _ownsPhotoLifecycleApiService;
  late final BuildingLifecycleApiService _buildingLifecycleApiService;
  late final bool _ownsBuildingLifecycleApiService;

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
    _ownsVisitLifecycleApiService = widget.visitLifecycleApiService == null;
    _visitLifecycleApiService =
        widget.visitLifecycleApiService ?? HttpVisitLifecycleApiService();
    _ownsPhotoLifecycleApiService = widget.photoLifecycleApiService == null;
    _photoLifecycleApiService =
        widget.photoLifecycleApiService ?? HttpPhotoLifecycleApiService();
    _ownsBuildingLifecycleApiService =
        widget.buildingLifecycleApiService == null;
    _buildingLifecycleApiService =
        widget.buildingLifecycleApiService ?? HttpBuildingLifecycleApiService();

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
    if (_ownsVisitLifecycleApiService) {
      _visitLifecycleApiService.close();
    }
    if (_ownsPhotoLifecycleApiService) {
      _photoLifecycleApiService.close();
    }
    if (_ownsBuildingLifecycleApiService) {
      _buildingLifecycleApiService.close();
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

  Future<void> _hideVisit(BuildingVisit visit) async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final bool confirmed = await _confirmHideVisit(context, visit);
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
      await _visitLifecycleApiService.hideVisit(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
        visitId: visit.visitId,
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
      ).showSnackBar(const SnackBar(content: Text('訪問記録を非表示にしました。')));
    } on VisitLifecycleApiException catch (error) {
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
        _errorMessage = '訪問記録を非表示にできませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _openHiddenVisitManager() async {
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
        return _HiddenVisitManagerDialog(
          apiService: _visitLifecycleApiService,
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

    final bool confirmed = await _confirmPermanentPhotoDeletion(context, photo);
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

  Future<void> _hideBuilding() async {
    final BuildingDetailData? detail = _detail;
    if (detail == null || _isLoading) {
      return;
    }

    final bool confirmed = await _confirmHideBuilding(context, detail.building);
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
      await _buildingLifecycleApiService.hideBuilding(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      context.go(AppRoutes.browse);
    } on BuildingLifecycleApiException catch (error) {
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
        _errorMessage = '建物を非表示にできませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deleteBuildingPermanently() async {
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

    late final BuildingLifecycleSummary preview;
    try {
      preview = await _buildingLifecycleApiService.getBuildingDeletionPreview(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
      );
    } on BuildingLifecycleApiException catch (error) {
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
        _errorMessage = '削除対象を確認できませんでした。もう一度お試しください。';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });

    final bool confirmed = await _confirmPermanentBuildingDeletion(
      context,
      preview,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _buildingLifecycleApiService.deleteBuildingPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: detail.building.buildingId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      context.go(AppRoutes.browse);
    } on BuildingLifecycleApiException catch (error) {
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
        _errorMessage = '建物を完全削除できませんでした。もう一度お試しください。';
      });
    }
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
                    onHideBuilding: _hideBuilding,
                    onDeleteBuildingPermanently: _deleteBuildingPermanently,
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
                    onHideVisit: _hideVisit,
                    onManageHiddenVisits: _openHiddenVisitManager,
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
