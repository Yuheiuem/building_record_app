import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/features/record/presentation/record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初期状態では写真未選択の案内を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: _FakeRecordImagePickerService(
            const <RecordDraftPhoto>[],
          ),
        ),
      ),
    );

    expect(find.text('写真の下書き'), findsOneWidget);
    expect(find.text('写真がまだ選択されていません'), findsOneWidget);
    expect(find.byKey(const Key('select-record-photos')), findsOneWidget);
    expect(find.text('段階 3-1 / v0.9.0'), findsOneWidget);
  });

  testWidgets('複数写真を選択して個別に削除できる', (WidgetTester tester) async {
    final List<RecordDraftPhoto> photos = <RecordDraftPhoto>[
      RecordDraftPhoto(
        photoId: 'photo-1',
        fileName: 'one.png',
        mimeType: 'image/png',
        bytes: _onePixelPng,
      ),
      RecordDraftPhoto(
        photoId: 'photo-2',
        fileName: 'two.png',
        mimeType: 'image/png',
        bytes: _onePixelPng,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: RecordPage(
          authService: _FakeAuthService(),
          imagePickerService: _FakeRecordImagePickerService(photos),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('select-record-photos')));
    await tester.pumpAndSettle();

    expect(find.text('2枚'), findsOneWidget);
    expect(find.text('one.png'), findsOneWidget);
    expect(find.text('two.png'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-draft-photo-photo-1')));
    await tester.pumpAndSettle();

    expect(find.text('1枚'), findsOneWidget);
    expect(find.text('one.png'), findsNothing);
    expect(find.text('two.png'), findsOneWidget);
  });
}

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZrV8AAAAASUVORK5CYII=',
);

class _FakeRecordImagePickerService implements RecordImagePickerService {
  const _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
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
