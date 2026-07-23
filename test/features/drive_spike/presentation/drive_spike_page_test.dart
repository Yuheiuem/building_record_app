import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/drive_spike_photo.dart';
import 'package:building_record_app/data/models/selected_spike_image.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/drive_spike_api_service.dart';
import 'package:building_record_app/data/services/spike_image_picker_service.dart';
import 'package:building_record_app/features/drive_spike/presentation/drive_spike_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログインでは画像選択ボタンが無効である', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService.signedOut();

    await tester.pumpWidget(
      MaterialApp(
        home: DriveSpikePage(
          authService: authService,
          driveApiService: _FakeDriveSpikeApiService(),
          imagePickerService: _FakeImagePickerService(),
        ),
      ),
    );

    expect(find.text('非公開Drive保存・再表示'), findsOneWidget);
    final Finder button = find.widgetWithText(FilledButton, '画像を選択');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('画像を保存し認証付きで再表示できる', (WidgetTester tester) async {
    final Uint8List imageBytes = _tinyPngBytes();
    final _FakeDriveSpikeApiService apiService = _FakeDriveSpikeApiService(
      imageBytes: imageBytes,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DriveSpikePage(
          authService: _FakeAuthService.signedIn(),
          driveApiService: apiService,
          imagePickerService: _FakeImagePickerService(
            image: SelectedSpikeImage(
              fileName: 'test.png',
              mimeType: 'image/png',
              bytes: imageBytes,
            ),
          ),
        ),
      ),
    );

    final Finder selectButton = find.widgetWithText(FilledButton, '画像を選択');
    await tester.ensureVisible(selectButton);
    await tester.tap(selectButton);
    await tester.pumpAndSettle();

    expect(find.text('選択した画像'), findsOneWidget);

    final Finder saveButton = find.widgetWithText(
      FilledButton,
      '非公開Driveへ保存して再表示',
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(apiService.uploadCallCount, 1);
    expect(apiService.getCallCount, 1);
    expect(find.text('保存成功'), findsOneWidget);
    expect(find.text('再表示成功'), findsOneWidget);
    expect(find.text('Driveから認証付きで再取得した画像'), findsOneWidget);
    expect(find.text('PRIVATE'), findsNWidgets(2));
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService._({
    required GoogleAuthStatus status,
    AuthenticatedGoogleUser? user,
    String? idToken,
  }) : _status = status,
       _user = user,
       _idToken = idToken;

  factory _FakeAuthService.signedOut() {
    return _FakeAuthService._(status: GoogleAuthStatus.signedOut);
  }

  factory _FakeAuthService.signedIn() {
    return _FakeAuthService._(
      status: GoogleAuthStatus.signedIn,
      user: const AuthenticatedGoogleUser(
        email: 'test@example.com',
        displayName: 'テスト利用者',
      ),
      idToken: 'test-id-token',
    );
  }

  GoogleAuthStatus _status;
  AuthenticatedGoogleUser? _user;
  String? _idToken;

  @override
  GoogleAuthStatus get status => _status;

  @override
  AuthenticatedGoogleUser? get currentUser => _user;

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {
    _status = GoogleAuthStatus.signedOut;
    _user = null;
    _idToken = null;
    notifyListeners();
  }
}

class _FakeImagePickerService implements SpikeImagePickerService {
  _FakeImagePickerService({this.image});

  final SelectedSpikeImage? image;

  @override
  Future<SelectedSpikeImage?> pickSingleImage() async => image;
}

class _FakeDriveSpikeApiService implements DriveSpikeApiService {
  _FakeDriveSpikeApiService({Uint8List? imageBytes})
    : _imageBytes = imageBytes ?? _tinyPngBytes();

  final Uint8List _imageBytes;
  int uploadCallCount = 0;
  int getCallCount = 0;

  @override
  Future<DriveSpikeUploadResponse> uploadPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    uploadCallCount += 1;
    return DriveSpikeUploadResponse(
      requestId: requestId,
      serverTime: '2026-07-23T16:00:00+09:00',
      storageFileId: 'drive-file-id',
      fileName: 'spike_$photoId.png',
      mimeType: mimeType,
      byteSize: bytes.length,
      duplicate: false,
      sharingAccess: 'PRIVATE',
      stage: '0-4',
    );
  }

  @override
  Future<DriveSpikePhotoData> getPhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String storageFileId,
  }) async {
    getCallCount += 1;
    return DriveSpikePhotoData(
      requestId: requestId,
      serverTime: '2026-07-23T16:00:01+09:00',
      storageFileId: storageFileId,
      fileName: 'spike_photo.png',
      mimeType: 'image/png',
      byteSize: _imageBytes.length,
      sharingAccess: 'PRIVATE',
      stage: '0-4',
      bytes: _imageBytes,
    );
  }

  @override
  void close() {}
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
}
