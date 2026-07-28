import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/bootstrap_data.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({
    required this.authService,
    this.bootstrapApiService,
    super.key,
  });

  final AuthService authService;
  final BootstrapApiService? bootstrapApiService;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  late final BootstrapApiService _bootstrapApiService;
  late final bool _ownsBootstrapApiService;

  BootstrapData? _bootstrapData;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ownsBootstrapApiService = widget.bootstrapApiService == null;
    _bootstrapApiService =
        widget.bootstrapApiService ?? HttpBootstrapApiService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBootstrapData();
    });
  }

  @override
  void dispose() {
    if (_ownsBootstrapApiService) {
      _bootstrapApiService.close();
    }
    super.dispose();
  }

  Future<void> _loadBootstrapData() async {
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
      final BootstrapData result = await _bootstrapApiService.getBootstrapData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapData = result;
        _isLoading = false;
      });
    } on BootstrapApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'データを取得できませんでした。もう一度送信してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(
        authService: widget.authService,
        title: '地図・一覧で見る',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ConnectionCard(
                    data: _bootstrapData,
                    errorMessage: _errorMessage,
                    isLoading: _isLoading,
                    onRefresh: _loadBootstrapData,
                  ),
                  const SizedBox(height: 16),
                  _BrowseNextStepCard(data: _bootstrapData),
                  const SizedBox(height: 24),
                  const AppVersionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.data,
    required this.errorMessage,
    required this.isLoading,
    required this.onRefresh,
  });

  final BootstrapData? data;
  final String? errorMessage;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.table_chart_outlined,
                  color: colorScheme.primary,
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sheets・API接続',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Google Sheetsから建物とタグの初期データを取得します。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const _LoadingPanel()
            else if (errorMessage != null)
              _ErrorPanel(message: errorMessage!)
            else if (data != null)
              _SuccessPanel(data: data!)
            else
              const Text('まだデータを取得していません。'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isLoading ? '取得中' : '最新データを取得'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(child: Text('Google Sheetsからデータを取得しています。')),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.data});

  final BootstrapData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Sheets接続成功',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _CountChip(label: '建物', count: data.counts.buildings),
              _CountChip(label: '訪問', count: data.counts.visits),
              _CountChip(label: '写真', count: data.counts.photos),
              _CountChip(label: 'タグ', count: data.counts.tags),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Schema ${data.schemaVersion} / ${data.stage}',
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            'サーバー時刻 ${data.serverTime.toIso8601String()}',
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $count件'));
  }
}

class _BrowseNextStepCard extends StatelessWidget {
  const _BrowseNextStepCard({required this.data});

  final BootstrapData? data;

  @override
  Widget build(BuildContext context) {
    final bool hasBuildings = data?.buildings.isNotEmpty ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasBuildings ? '建物データを取得しました' : '建物データはまだありません',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasBuildings
                  ? '次の段階で、取得した建物を地図と一覧へ表示します。'
                  : '段階2-1では保存先と読み取りAPIを整備しました。建物登録は後続段階で実装します。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
