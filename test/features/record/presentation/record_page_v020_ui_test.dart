import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/features/record/presentation/record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('写真の選択・変換中は現在の処理ステータスを表示する', (
    WidgetTester tester,
  ) async {
    final _ProgressImagePickerService picker = _ProgressImagePickerService();

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: picker,
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData(0)),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('select-record-photos')));
    await tester.pump();

    expect(
      find.byKey(const Key('record-photo-preparation-status')),
      findsOneWidget,
    );
    expect(find.text('写真を選択・変換しています。'), findsOneWidget);

    picker.complete(<RecordDraftPhoto>[_photo(1)]);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('record-photo-preparation-status')),
      findsNothing,
    );
  });

  testWidgets('写真が増えても写真一覧は画面高の約7割以内で内部スクロールする', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<RecordDraftPhoto> photos = List<RecordDraftPhoto>.generate(
      12,
      (int index) => _photo(index + 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: _ImmediateImagePickerService(photos),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData(0)),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('select-record-photos')));
    await tester.pumpAndSettle();

    final Finder scrollArea = find.byKey(
      const Key('record-photo-draft-scroll'),
    );
    expect(scrollArea, findsOneWidget);
    expect(tester.getSize(scrollArea).height, lessThanOrEqualTo(560.1));
  });

  testWidgets('既存建物が増えても検索結果だけを画面高の約7割以内でスクロールする', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: const _ImmediateImagePickerService(
            <RecordDraftPhoto>[],
          ),
          bootstrapApiService: _FakeBootstrapApiService(_bootstrapData(30)),
          locationService: _FakeRecordLocationService(_gpsLocation()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder existingMode = find.byKey(
      const Key('record-building-mode-existing'),
    );
    await tester.ensureVisible(existingMode);
    await tester.pumpAndSettle();
    await tester.tap(existingMode);
    await tester.pumpAndSettle();

    final Finder scrollArea = find.byKey(
      const Key('existing-building-results-scroll'),
    );
    expect(scrollArea, findsOneWidget);
    expect(tester.getSize(scrollArea).height, lessThanOrEqualTo(560.1));
    expect(find.text('先頭20件を表示しています。検索文字を追加してください。'), findsOneWidget);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZrV8AAAAASUVORK5CYII=',
);

RecordDraftPhoto _photo(int index) {
  return RecordDraftPhoto(
    photoId: 'photo-$index',
    fileName: 'photo-$index.png',
    mimeType: 'image/png',
    bytes: _onePixelPng,
  );
}

RecordDraftLocation _gpsLocation() {
  return RecordDraftLocation(
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 8.4,
    source: RecordLocationSource.gps,
    capturedAt: DateTime.parse('2026-08-21T15:00:00+09:00'),
  );
}

BootstrapData _bootstrapData(int buildingCount) {
  return BootstrapData(
    requestId: 'request-bootstrap',
    serverTime: DateTime.parse('2026-08-21T15:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '5-4A.13',
    buildings: List<Building>.generate(
      buildingCount,
      (int index) => Building(
        buildingId: 'building-$index',
        buildingName: '建物 ${index + 1}',
        searchName: '建物 ${index + 1}',
        latitude: 35.68 + index / 10000,
        longitude: 139.76 + index / 10000,
        address: '東京都 テスト ${index + 1}',
        designTags: const <String>[],
        salesTags: const <String>[],
        constructionTags: const <String>[],
        driveFolderId: null,
        coverPhotoId: null,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
      growable: false,
    ),
    tags: const <BuildingTag>[],
    counts: BootstrapCounts(
      buildings: buildingCount,
      visits: 0,
      photos: 0,
      tags: 0,
    ),
  );
}

class _ImmediateImagePickerService implements RecordImagePickerService {
  const _ImmediateImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
}

class _ProgressImagePickerService
    implements RecordImagePickerService, RecordImagePickerProgressService {
  final Completer<List<RecordDraftPhoto>> _completer =
      Completer<List<RecordDraftPhoto>>();

  void complete(List<RecordDraftPhoto> photos) {
    _completer.complete(photos);
  }

  @override
  Future<List<RecordDraftPhoto>> pickImages() => _completer.future;

  @override
  Future<List<RecordDraftPhoto>> pickImagesWithProgress({
    required RecordImagePickProgressCallback onProgress,
  }) {
    onProgress(
      const RecordImagePickProgress(
        phase: RecordImagePickProgressPhase.selectingAndConverting,
      ),
    );
    return _completer.future;
  }
}

class _FakeBootstrapApiService implements BootstrapApiService {
  const _FakeBootstrapApiService(this.data);

  final BootstrapData data;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    return data;
  }

  @override
  void close() {}
}

class _FakeRecordLocationService implements RecordLocationService {
  const _FakeRecordLocationService(this.location);

  final RecordDraftLocation location;

  @override
  Future<RecordDraftLocation> getCurrentLocation() async => location;
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser => const AuthenticatedGoogleUser(
    email: 'test@example.com',
    displayName: 'テスト利用者',
  );

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}
