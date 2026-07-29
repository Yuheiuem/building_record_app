import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/record_draft_location.dart';

abstract interface class RecordLocationService {
  Future<RecordDraftLocation> getCurrentLocation();
}

class GeolocatorRecordLocationService implements RecordLocationService {
  @override
  Future<RecordDraftLocation> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const RecordLocationException('端末の位置情報が無効です。設定を確認してください。');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const RecordLocationException('位置情報の利用が許可されませんでした。');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const RecordLocationException(
        '位置情報の利用が拒否されています。ブラウザまたは端末の設定から許可してください。',
      );
    }

    try {
      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      );
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      return RecordDraftLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        source: RecordLocationSource.gps,
        capturedAt: DateTime.now(),
      );
    } on TimeoutException {
      throw const RecordLocationException(
        '現在地を取得できませんでした。電波状況を確認して、もう一度お試しください。',
      );
    } on RecordLocationException {
      rethrow;
    } catch (_) {
      throw const RecordLocationException('現在地を取得できませんでした。もう一度お試しください。');
    }
  }
}

class RecordLocationException implements Exception {
  const RecordLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
