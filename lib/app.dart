import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/drive_spike/presentation/drive_spike_page.dart';

class BuildingRecordApp extends StatelessWidget {
  const BuildingRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.workingTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315D67),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
        useMaterial3: true,
      ),
      home: const DriveSpikePage(),
    );
  }
}
