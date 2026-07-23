import 'package:flutter/material.dart';

import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(authService: authService, title: '地図・一覧で見る'),
      body: const _BrowsePlaceholder(),
    );
  }
}

class _BrowsePlaceholder extends StatelessWidget {
  const _BrowsePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '閲覧画面の入口',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '段階1-1ではURLと画面遷移を整備しました。地図・一覧・検索・建物詳細は後続段階で実装します。',
                    textAlign: TextAlign.center,
                  ),
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
