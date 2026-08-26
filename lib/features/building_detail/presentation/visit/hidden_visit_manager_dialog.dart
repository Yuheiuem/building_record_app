part of '../building_detail_page.dart';

class _HiddenVisitManagerDialog extends StatefulWidget {
  const _HiddenVisitManagerDialog({
    required this.apiService,
    required this.buildingId,
    required this.idToken,
  });

  final VisitLifecycleApiService apiService;
  final String buildingId;
  final String idToken;

  @override
  State<_HiddenVisitManagerDialog> createState() =>
      _HiddenVisitManagerDialogState();
}

class _HiddenVisitManagerDialogState extends State<_HiddenVisitManagerDialog> {
  final List<VisitLifecycleSummary> _visits = <VisitLifecycleSummary>[];
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
      final List<VisitLifecycleSummary> visits = await widget.apiService
          .getHiddenBuildingVisits(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: widget.idToken,
            buildingId: widget.buildingId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _visits
          ..clear()
          ..addAll(visits);
        _isLoading = false;
      });
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
        _errorMessage = '非表示の訪問記録を取得できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _restore(VisitLifecycleSummary summary) async {
    if (_isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.restoreVisit(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        visitId: summary.visit.visitId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _visits.removeWhere(
          (VisitLifecycleSummary item) =>
              item.visit.visitId == summary.visit.visitId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訪問記録を復元しました。')));
    } on VisitLifecycleApiException catch (error) {
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
        _errorMessage = '訪問記録を復元できませんでした。もう一度お試しください。';
      });
    }
  }

  Future<void> _deletePermanently(VisitLifecycleSummary summary) async {
    if (_isMutating) {
      return;
    }
    final bool confirmed = await _confirmPermanentVisitDeletion(
      context,
      summary,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await widget.apiService.deleteVisitPermanently(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: widget.idToken,
        buildingId: widget.buildingId,
        visitId: summary.visit.visitId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _visits.removeWhere(
          (VisitLifecycleSummary item) =>
              item.visit.visitId == summary.visit.visitId,
        );
        _isMutating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訪問記録と写真を完全に削除しました。')));
    } on VisitLifecycleApiException catch (error) {
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
        _errorMessage = '訪問記録を完全削除できませんでした。もう一度お試しください。';
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
          title: const Text('非表示の訪問を管理'),
          leading: IconButton(
            key: const Key('close-hidden-visit-manager'),
            onPressed: _isMutating ? null : _close,
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            IconButton(
              key: const Key('refresh-hidden-visits'),
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
                              '非表示の訪問記録は写真を含めてDrive上に残っているため復元できます。'
                              '「完全に削除」を選ぶと、この訪問に紐づく元画像とサムネイルも削除され、復元できなくなります。',
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
                  if (_isLoading && _visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_visits.isEmpty)
                    const _SectionEmptyState(
                      icon: Icons.event_available_outlined,
                      message: '非表示の訪問記録はありません。',
                    )
                  else
                    ..._visits.map((VisitLifecycleSummary summary) {
                      final BuildingVisit visit = summary.visit;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          key: ValueKey<String>(
                            'hidden-visit-${visit.visitId}',
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  _formatDateTime(visit.visitedAt),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (visit.impression.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    visit.impression,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    Text('写真 ${summary.photoCount}枚'),
                                    Text(
                                      '元画像容量 ${_formatBytes(summary.photoBytes)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    FilledButton.tonalIcon(
                                      key: ValueKey<String>(
                                        'restore-hidden-visit-${visit.visitId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _restore(summary),
                                      icon: const Icon(Icons.restore),
                                      label: const Text('復元'),
                                    ),
                                    TextButton.icon(
                                      key: ValueKey<String>(
                                        'delete-hidden-visit-${visit.visitId}',
                                      ),
                                      onPressed: _isMutating
                                          ? null
                                          : () => _deletePermanently(summary),
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
