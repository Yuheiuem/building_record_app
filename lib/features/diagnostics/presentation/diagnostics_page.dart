import 'package:flutter/material.dart';

import '../../../data/services/auth_service.dart';
import '../../../data/services/storage_monitor_api_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../../shared/widgets/storage_monitor_card.dart';
import '../../drive_spike/presentation/drive_spike_page.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({
    required this.authService,
    this.storageMonitorApiService,
    super.key,
  });

  final AuthService authService;
  final StorageMonitorApiService? storageMonitorApiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(authService: authService, title: '技術診断'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: StorageMonitorCard(
              authService: authService,
              apiService: storageMonitorApiService,
            ),
          ),
          Expanded(child: DriveSpikePage(authService: authService)),
        ],
      ),
    );
  }
}
