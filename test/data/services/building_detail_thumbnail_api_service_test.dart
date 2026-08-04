import 'dart:convert';

import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('サムネイル取得actionを送信して画像データを読み取る', () async {
    late Map<String, dynamic> sentBody;
    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'ok': true,
          'requestId': 'request-thumbnail-1234',
          'serverTime': '2026-08-04T10:00:00+09:00',
          'data': <String, Object?>{
            'photoId': 'photo-thumbnail-1234',
            'fileName': 'photo-thumbnail-1234.jpg',
            'mimeType': 'image/jpeg',
            'byteSize': 4,
            'base64Data': 'AQIDBA==',
            'source': 'thumbnail',
            'stage': '5-2B',
          },
          'errorCode': null,
          'message': null,
        }),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    final HttpBuildingDetailApiService service = HttpBuildingDetailApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );
    addTearDown(service.close);

    final result = await service.getPhotoThumbnailData(
      requestId: 'request-thumbnail-1234',
      clientVersion: 'v0.17.1',
      idToken: 'test-id-token',
      photoId: 'photo-thumbnail-1234',
    );

    expect(sentBody['action'], 'getPhotoThumbnailData');
    expect(sentBody['requestId'], 'request-thumbnail-1234');
    expect(sentBody['clientVersion'], 'v0.17.1');
    expect(sentBody['idToken'], 'test-id-token');
    expect(sentBody['payload'], <String, Object?>{
      'photoId': 'photo-thumbnail-1234',
    });
    expect(result.photoId, 'photo-thumbnail-1234');
    expect(result.mimeType, 'image/jpeg');
    expect(result.bytes, <int>[1, 2, 3, 4]);
    expect(result.stage, '5-2B');
  });
}
