import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/building_lifecycle_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.authService,
    this.buildingLifecycleApiService,
    super.key,
  });

  static const double compactBreakpoint = 720;

  final AuthService authService;
  final BuildingLifecycleApiService? buildingLifecycleApiService;

  Future<void> _openHiddenBuildingManager(BuildContext context) async {
    final String? idToken = authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Googleログイン情報を取得できませんでした。')));
      return;
    }

    final bool ownsApiService = buildingLifecycleApiService == null;
    final BuildingLifecycleApiService apiService =
        buildingLifecycleApiService ?? HttpBuildingLifecycleApiService();
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return _HiddenBuildingManagerDialog(
            apiService: apiService,
            idToken: idToken,
          );
        },
      );
    } finally {
      if (ownsApiService) {
        apiService.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.workingTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => unawaited(authService.signOut()),
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isCompact = constraints.maxWidth < compactBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 32,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _WelcomeHeader(authService: authService),
                      const SizedBox(height: 24),
                      if (isCompact)
                        const _CompactActionLayout()
                      else
                        const _WideActionLayout(),
                      const SizedBox(height: 16),
                      _HiddenBuildingsActionCard(
                        onTap: () => _openHiddenBuildingManager(context),
                      ),
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

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final AuthenticatedGoogleUser? user = authService.currentUser;
    final String displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : '利用者';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$displayNameさん',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '記録するか、これまでの建築を振り返るかを選んでください。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompactActionLayout extends StatelessWidget {
  const _CompactActionLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HomeActionCard(
          key: Key('primary-record-action'),
          icon: Icons.add_a_photo_outlined,
          title: '建築を記録する',
          description: '写真・位置・メモを登録します。',
          route: AppRoutes.record,
          emphasized: true,
        ),
        SizedBox(height: 16),
        _HomeActionCard(
          icon: Icons.map_outlined,
          title: '地図・一覧で見る',
          description: '登録した建築を地図や一覧で探します。',
          route: AppRoutes.browse,
        ),
        SizedBox(height: 16),
        _DiagnosticsActionCard(),
      ],
    );
  }
}

class _WideActionLayout extends StatelessWidget {
  const _WideActionLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _HomeActionCard(
                  key: Key('primary-browse-action'),
                  icon: Icons.map_outlined,
                  title: '地図・一覧で見る',
                  description: '登録した建築を地図と一覧から探し、詳細や訪問履歴を確認します。',
                  route: AppRoutes.browse,
                  emphasized: true,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _HomeActionCard(
                  icon: Icons.add_a_photo_outlined,
                  title: '建築を記録する',
                  description: '写真・位置・メモを登録します。',
                  route: AppRoutes.record,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        _DiagnosticsActionCard(),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: emphasized ? colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                size: emphasized ? 42 : 34,
                color: emphasized
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasized ? colorScheme.onPrimaryContainer : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: emphasized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward,
                  color: emphasized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsActionCard extends StatelessWidget {
  const _DiagnosticsActionCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.go(AppRoutes.diagnostics),
        leading: const Icon(Icons.science_outlined),
        title: const Text('技術診断を開く'),
        subtitle: const Text('Googleログイン・Apps Script・非公開Drive保存を確認します。'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _HiddenBuildingsActionCard extends StatelessWidget {
  const _HiddenBuildingsActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: const Key('manage-hidden-buildings'),
        onTap: onTap,
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('非表示建物を管理'),
        subtitle: const Text('非表示にした建物の復元・完全削除を行います。'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _HiddenBuildingManagerDialog extends StatefulWidget {
  const _HiddenBuildingManagerDialog({
    required this.apiService,
    required this.idToken,
  });

  final BuildingLifecycleApiService apiService;
  final String idToken;

  @override
  State<_HiddenBuildingManagerDialog> createState() =>
      _HiddenBuildingManagerDialogState();
}

class _HiddenBuildingManagerDialogState
    extends State<_HiddenBuildingManagerDialog> {
  List<BuildingLifecycleSummary> _buildings =
      const <BuildingLifecycleSummary>[];
  bool _isLoading = false;
  String? _busyBuildingId;
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
      final List<BuildingLifecycleSummary> result = await widget.apiService
          .getHiddenBuildings(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: widget.idToken,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _buildings = result;
        _isLoading = false;
      });
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
        _errorMessage = '非表示建物を取得できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _restore(BuildingLifecycleSummary summary) async {
    if (_busyBuildingId != null) {
      return;
    }
    setState(() {
      _busyBuildingId = summary.building.buildingId;
      _errorMessage = null;
    });

    try {
      await widget.apiService.restoreBuilding(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: summary.building.buildingId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buildings = _buildings
            .where(
              (BuildingLifecycleSummary item) =>
                  item.building.buildingId != summary.building.buildingId,
            )
            .toList(growable: false);
        _busyBuildingId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('建物を復元しました。')));
    } on BuildingLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = '建物を復元できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deletePermanently(BuildingLifecycleSummary summary) async {
    if (_busyBuildingId != null) {
      return;
    }

    setState(() {
      _busyBuildingId = summary.building.buildingId;
      _errorMessage = null;
    });

    late final BuildingLifecycleSummary latest;
    try {
      latest = await widget.apiService.getBuildingDeletionPreview(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: summary.building.buildingId,
      );
    } on BuildingLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = '削除対象を確認できませんでした。もう一度お試しください。';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _busyBuildingId = null;
    });

    final bool confirmed = await _confirmBuildingPermanentDeletion(
      context,
      latest,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _busyBuildingId = summary.building.buildingId;
      _errorMessage = null;
    });
    try {
      await widget.apiService.deleteBuildingPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: summary.building.buildingId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buildings = _buildings
            .where(
              (BuildingLifecycleSummary item) =>
                  item.building.buildingId != summary.building.buildingId,
            )
            .toList(growable: false);
        _busyBuildingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('建物と写真をGoogle Driveから完全に削除しました。')),
      );
    } on BuildingLifecycleApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyBuildingId = null;
        _errorMessage = '建物を完全削除できませんでした。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非表示建物を管理'),
          leading: IconButton(
            key: const Key('close-hidden-building-manager'),
            onPressed: _busyBuildingId == null
                ? () => Navigator.of(context).pop()
                : null,
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            IconButton(
              key: const Key('refresh-hidden-buildings'),
              onPressed: _busyBuildingId == null && !_isLoading ? _load : null,
              tooltip: '再読み込み',
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
                  Text(
                    '非表示は復元できます。完全削除するとGoogle Driveの写真も削除され、元に戻せません。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_errorMessage!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_isLoading && _buildings.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '復元できる非表示建物はありません。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._buildings.map((BuildingLifecycleSummary summary) {
                      final bool busy =
                          _busyBuildingId == summary.building.buildingId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          key: ValueKey<String>(
                            'hidden-building-${summary.building.buildingId}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  summary.building.buildingName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (summary.building.address !=
                                    null) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(summary.building.address!),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    Text('訪問 ${summary.visitCount}件'),
                                    Text('写真 ${summary.photoCount}枚'),
                                    Text(
                                      '元画像 ${_formatBuildingLifecycleBytes(summary.photoBytes)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      key: ValueKey<String>(
                                        'restore-building-${summary.building.buildingId}',
                                      ),
                                      onPressed: busy || _busyBuildingId != null
                                          ? null
                                          : () => _restore(summary),
                                      icon: const Icon(Icons.restore),
                                      label: const Text('復元'),
                                    ),
                                    TextButton.icon(
                                      key: ValueKey<String>(
                                        'delete-building-${summary.building.buildingId}',
                                      ),
                                      onPressed: busy || _busyBuildingId != null
                                          ? null
                                          : () => _deletePermanently(summary),
                                      icon: const Icon(Icons.delete_forever),
                                      label: const Text('完全削除'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
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
              if (_isLoading)
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

Future<bool> _confirmBuildingPermanentDeletion(
  BuildContext context,
  BuildingLifecycleSummary summary,
) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('建物を完全に削除しますか？'),
        content: Text(
          '「${summary.building.buildingName}」を完全に削除します。\n\n'
          '訪問 ${summary.visitCount}件\n'
          '写真 ${summary.photoCount}枚\n'
          '元画像容量 ${_formatBuildingLifecycleBytes(summary.photoBytes)}\n\n'
          'Google Driveの元画像とサムネイルも永久削除されます。'
          'この操作は元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm-delete-building-permanently'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('完全に削除'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

String _formatBuildingLifecycleBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
