import 'package:flutter/material.dart';

import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/authenticated_app_bar.dart';
import '../../drive_spike/presentation/drive_spike_page.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(authService: authService, title: '技術診断'),
      body: DriveSpikePage(authService: authService),
    );
  }
}
