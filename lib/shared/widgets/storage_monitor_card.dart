import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/storage_monitor_api_service.dart';

enum _StorageRisk { normal, warning, critical }

class StorageMonitorCard extends StatefulWidget {
  const StorageMonitorCard({
    required this.authService,
    this.apiService,
    super.key,
  });

  final AuthService authService;
  final StorageMonitorApiService? apiService;

  @override
  State<StorageMonitorCard> createState() => _StorageMonitorCardState();
}

class _StorageMonitorCardState extends State<StorageMonitorCard> {
  late final StorageMonitorApiService _apiService;
  late final bool _ownsApiService;

  StorageUsageSummary? _summary;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ownsApiService = widget.apiService == null;
    _apiService = widget.apiService ?? HttpStorageMonitorApiService();
    if (widget.apiService != null || kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    if (_ownsApiService) {
      _apiService.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) {
      return;
    }

    final String? idToken = widget.authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      setState(() {
        _errorMessage = 'Googleログイン情報を取得できませんでした。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final StorageUsageSummary summary = await _apiService.getStorageUsage(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } on StorageMonitorApiException catch (error) {
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
        _errorMessage = '容量情報を取得できませんでした。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final StorageUsageSummary? summary = _summary;
    return Card(
      key: const Key('storage-monitor-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.storage_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '容量監視',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('refresh-storage-monitor'),
                  onPressed: _isLoading ? null : _load,
                  tooltip: '容量を再取得',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_isLoading) ...<Widget>[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (summary != null) ...<Widget>[
              const SizedBox(height: 12),
              _StorageQuotaView(summary: summary),
            ] else if (!_isLoading && _errorMessage == null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Googleアカウントの保存容量と、このアプリの元画像容量を確認します。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('load-storage-monitor'),
                onPressed: _load,
                icon: const Icon(Icons.data_usage),
                label: const Text('容量を確認'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StorageQuotaView extends StatelessWidget {
  const _StorageQuotaView({required this.summary});

  final StorageUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final int? limitBytes = summary.quotaLimitBytes;
    final double? usageRatio = summary.usageRatio;
    final _StorageRisk risk = _storageRisk(summary);
    final String usageText = limitBytes == null
        ? _formatStorageBytes(summary.quotaUsageBytes)
        : '${_formatStorageBytes(summary.quotaUsageBytes)} / '
              '${_formatStorageBytes(limitBytes)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Googleアカウント使用量'),
                  const SizedBox(height: 4),
                  Text(
                    usageText,
                    key: const Key('storage-account-usage'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StorageRiskChip(risk: risk),
          ],
        ),
        if (usageRatio != null) ...<Widget>[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            key: const Key('storage-usage-progress'),
            value: usageRatio.clamp(0.0, 1.0).toDouble(),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text('使用率 ${(usageRatio * 100).toStringAsFixed(1)}%'),
              const Spacer(),
              if (summary.remainingBytes != null)
                Text('残り ${_formatStorageBytes(summary.remainingBytes!)}'),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _storageRiskMessage(risk),
          key: const Key('storage-risk-message'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: risk == _StorageRisk.normal
                ? FontWeight.normal
                : FontWeight.w700,
            color: risk == _StorageRisk.critical
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
        const Divider(height: 28),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: <Widget>[
            Text('Drive内 ${_formatStorageBytes(summary.driveUsageBytes)}'),
            Text('ゴミ箱 ${_formatStorageBytes(summary.driveTrashBytes)}'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'このアプリの元画像 '
          '${_formatStorageBytes(summary.appOriginalBytes)} '
          '（${summary.appStoredPhotoCount}枚）',
          key: const Key('storage-app-originals'),
        ),
        const SizedBox(height: 4),
        Text(
          '表示中 ${summary.appActivePhotoCount}枚／'
          '非表示 ${summary.appHiddenPhotoCount}枚',
        ),
        if (summary.appHiddenPhotoCount > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '非表示写真もDrive容量を使用します。不要なら完全削除すると容量を回収できます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'アプリ容量は元画像の合計です。サムネイル等はGoogleアカウント使用量には含まれますが、'
          'この内訳には含めていません。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StorageRiskChip extends StatelessWidget {
  const _StorageRiskChip({required this.risk});

  final _StorageRisk risk;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon) = switch (risk) {
      _StorageRisk.normal => ('余裕あり', Icons.check_circle_outline),
      _StorageRisk.warning => ('注意', Icons.warning_amber_outlined),
      _StorageRisk.critical => ('危険', Icons.error_outline),
    };
    return Chip(
      key: const Key('storage-risk-chip'),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

_StorageRisk _storageRisk(StorageUsageSummary summary) {
  final double? ratio = summary.usageRatio;
  if (ratio == null) {
    return _StorageRisk.normal;
  }
  if (ratio >= AppConfig.storageCriticalUsageRatio) {
    return _StorageRisk.critical;
  }
  if (ratio >= AppConfig.storageWarningUsageRatio) {
    return _StorageRisk.warning;
  }
  return _StorageRisk.normal;
}

String _storageRiskMessage(_StorageRisk risk) {
  return switch (risk) {
    _StorageRisk.normal => '容量には余裕があります。',
    _StorageRisk.warning => '使用率が80%を超えています。不要な写真を整理して空きを確保してください。',
    _StorageRisk.critical => '使用率が90%を超えています。完全削除や容量引っ越しの準備を検討してください。',
  };
}

String _formatStorageBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
