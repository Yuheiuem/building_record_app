import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/features/record/domain/record_submission_draft_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validate', () {
    test('写真がない場合は既存の検証文言を返す', () {
      expect(_validate(hasPhotos: false), '写真を1枚以上選択してください。');
    });

    test('新規建物名の未入力と文字数超過を検証する', () {
      expect(_validate(newBuildingName: '   '), '建物名を入力してください。');
      expect(
        _validate(newBuildingName: List<String>.filled(101, '建').join()),
        '建物名は100文字以内で入力してください。',
      );
    });

    test('既存建物・位置・IDトークンの不足を検証する', () {
      expect(
        _validate(isNewBuilding: false, hasSelectedExistingBuilding: false),
        '登録済みの建物を選択してください。',
      );
      expect(_validate(hasVisitLocation: false), '位置情報を取得してください。');
      expect(_validate(idToken: null), 'Googleログイン情報を取得できませんでした。');
    });

    test('必要な入力が揃っていればnullを返す', () {
      expect(_validate(), isNull);
      expect(
        _validate(isNewBuilding: false, hasSelectedExistingBuilding: true),
        isNull,
      );
    });
  });

  group('build', () {
    test('新規建物の文字列を整形しタグIDを並べ替える', () {
      final RecordDraftLocation location = _location();
      final RecordSubmissionDraft draft = RecordSubmissionDraftBuilder.build(
        isNewBuilding: true,
        newBuildingName: '  新規建物  ',
        newDesignTagIds: const <String>{'design-b', 'design-a'},
        newSalesTagIds: const <String>{'sales-b', 'sales-a'},
        newConstructionTagIds: const <String>{
          'construction-b',
          'construction-a',
        },
        pendingExistingDesignTagIds: const <String>{'ignored-design'},
        pendingExistingSalesTagIds: const <String>{'ignored-sales'},
        pendingExistingConstructionTagIds: const <String>{
          'ignored-construction',
        },
        buildingId: 'building-new',
        visitId: 'visit-new',
        visitedAt: DateTime.parse('2026-08-26T10:00:00+09:00'),
        triggerTagIds: const <String>{'trigger-b', 'trigger-a'},
        impression: '  感想  ',
        location: location,
        expectedPhotoCount: 3,
      );

      expect(draft.buildingMode, 'new');
      expect(draft.buildingName, '新規建物');
      expect(draft.designTagIds, <String>['design-a', 'design-b']);
      expect(draft.salesTagIds, <String>['sales-a', 'sales-b']);
      expect(draft.constructionTagIds, <String>[
        'construction-a',
        'construction-b',
      ]);
      expect(draft.triggerTagIds, <String>['trigger-a', 'trigger-b']);
      expect(draft.impression, '感想');
      expect(draft.location, same(location));
      expect(
        () => draft.designTagIds.add('design-c'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('既存建物では今回追加するタグだけを送信対象にする', () {
      final RecordSubmissionDraft draft = RecordSubmissionDraftBuilder.build(
        isNewBuilding: false,
        newBuildingName: '送信しない建物名',
        newDesignTagIds: const <String>{'new-design'},
        newSalesTagIds: const <String>{'new-sales'},
        newConstructionTagIds: const <String>{'new-construction'},
        pendingExistingDesignTagIds: const <String>{
          'existing-design-b',
          'existing-design-a',
        },
        pendingExistingSalesTagIds: const <String>{'existing-sales'},
        pendingExistingConstructionTagIds: const <String>{
          'existing-construction',
        },
        buildingId: 'building-existing',
        visitId: 'visit-existing',
        visitedAt: DateTime.parse('2026-08-26T11:00:00+09:00'),
        triggerTagIds: const <String>{},
        impression: '',
        location: _location(),
        expectedPhotoCount: 1,
      );

      expect(draft.buildingMode, 'existing');
      expect(draft.buildingName, isNull);
      expect(draft.designTagIds, <String>[
        'existing-design-a',
        'existing-design-b',
      ]);
      expect(draft.salesTagIds, <String>['existing-sales']);
      expect(draft.constructionTagIds, <String>['existing-construction']);
    });

    test('1枚保存用RecordPreparationPayloadへ同じ値を変換する', () {
      final RecordDraftLocation location = _location();
      final DateTime visitedAt = DateTime.parse('2026-08-26T12:00:00+09:00');
      final RecordSubmissionDraft draft = RecordSubmissionDraftBuilder.build(
        isNewBuilding: true,
        newBuildingName: 'Payload建物',
        newDesignTagIds: const <String>{'design-1'},
        newSalesTagIds: const <String>{'sales-1'},
        newConstructionTagIds: const <String>{'construction-1'},
        pendingExistingDesignTagIds: const <String>{},
        pendingExistingSalesTagIds: const <String>{},
        pendingExistingConstructionTagIds: const <String>{},
        buildingId: 'building-payload',
        visitId: 'visit-payload',
        visitedAt: visitedAt,
        triggerTagIds: const <String>{'trigger-1'},
        impression: 'Payload感想',
        location: location,
        expectedPhotoCount: 1,
      );

      final payload = draft.toRecordPreparationPayload(
        requestId: 'request-payload',
      );

      expect(payload.requestId, 'request-payload');
      expect(payload.buildingMode, 'new');
      expect(payload.buildingId, 'building-payload');
      expect(payload.visitId, 'visit-payload');
      expect(payload.buildingName, 'Payload建物');
      expect(payload.designTagIds, <String>['design-1']);
      expect(payload.salesTagIds, <String>['sales-1']);
      expect(payload.constructionTagIds, <String>['construction-1']);
      expect(payload.visitedAt, visitedAt);
      expect(payload.triggerTagIds, <String>['trigger-1']);
      expect(payload.impression, 'Payload感想');
      expect(payload.latitude, location.latitude);
      expect(payload.longitude, location.longitude);
      expect(payload.accuracyM, location.accuracyM);
      expect(payload.locationSource, location.source.apiValue);
      expect(payload.expectedPhotoCount, 1);
    });
  });
}

String? _validate({
  bool hasPhotos = true,
  bool isNewBuilding = true,
  String newBuildingName = '建物名',
  bool hasSelectedExistingBuilding = true,
  bool hasVisitLocation = true,
  String? idToken = 'id-token',
}) {
  return RecordSubmissionDraftBuilder.validate(
    hasPhotos: hasPhotos,
    isNewBuilding: isNewBuilding,
    newBuildingName: newBuildingName,
    hasSelectedExistingBuilding: hasSelectedExistingBuilding,
    hasVisitLocation: hasVisitLocation,
    idToken: idToken,
  );
}

RecordDraftLocation _location() {
  return RecordDraftLocation(
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 8.4,
    source: RecordLocationSource.gps,
    capturedAt: DateTime.parse('2026-08-26T09:00:00+09:00'),
  );
}
