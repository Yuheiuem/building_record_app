import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'data/services/auth_service.dart';
import 'data/services/google_auth_service.dart';

class BuildingRecordApp extends StatefulWidget {
  const BuildingRecordApp({super.key, this.authService, this.initialLocation});

  final AuthService? authService;
  final String? initialLocation;

  @override
  State<BuildingRecordApp> createState() => _BuildingRecordAppState();
}

class _BuildingRecordAppState extends State<BuildingRecordApp> {
  late final AuthService _authService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? GoogleAuthService.instance;
    _router = createAppRouter(
      authService: _authService,
      initialLocation: widget.initialLocation,
    );
    unawaited(_authService.initialize());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.workingTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315D67),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
        useMaterial3: true,
      ),
    );
  }
}
