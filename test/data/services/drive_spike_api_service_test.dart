import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/data/models/drive_spike_photo.dart';
import 'package:building_record_app/data/services/drive_spike_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('IDトークンとBase64画像をApps Scriptへ送信する', () async {
    late Map<String, dynamic> sentBody;
    final Uint8List imageBytes = Uint8List.fromList(<int>[1, 2, 3]);

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-upload',
        'serverTime': '2026-07-23T16:00:00+09:00',
        'data': <String, dynamic>{
          'storageFileId': 'drive-file-id',
          'fileName': 'spike_photo.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': 3,
          'duplicate': false,
          'sharingAccess': 'PRIVATE',
          'stage': '0-4',
        },
        'errorCode': null,
        'message': null,
      });
    });

    final HttpDriveSpikeApiService service = HttpDriveSpikeApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final DriveSpikeUploadResponse response = await service.uploadPhoto(
      requestId: 'request-upload',
      clientVersion: 'v0.5.0',
      idToken: 'test-id-token',
      photoId: 'photo-id-1234',
      fileName: 'source.jpg',
      mimeType: 'image/jpeg',
      bytes: imageBytes,
    );

    expect(sentBody['action'], 'uploadSpikePhoto');
    expect(sentBody['idToken'], 'test-id-token');
    expect(sentBody['clientVersion'], 'v0.5.0');
    expect(
      (sentBody['payload'] as Map<String, dynamic>)['base64Data'],
      base64Encode(imageBytes),
    );
    expect(response.storageFileId, 'drive-file-id');
    expect(response.sharingAccess, 'PRIVATE');

    service.close();
  });

  test('認証付きでDrive画像を再取得する', () async {
    late Map<String, dynamic> sentBody;
    final Uint8List imageBytes = Uint8List.fromList(<int>[4, 5, 6]);

    final MockClient client = MockClient((http.Request request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(<String, dynamic>{
        'ok': true,
        'requestId': 'request-get',
        'serverTime': '2026-07-23T16:00:01+09:00',
        'data': <String, dynamic>{
          'storageFileId': 'drive-file-id',
          'fileName': 'spike_photo.jpg',
          'mimeType': 'image/jpeg',
          'byteSize': imageBytes.length,
          'base64Data': base64Encode(imageBytes),
          'sharingAccess': 'PRIVATE',
          'stage': '0-4',
        },
        'errorCode': null,
        'message': null,
      });
    });

    final HttpDriveSpikeApiService service = HttpDriveSpikeApiService(
      client: client,
      endpoint: Uri.parse('https://example.com/exec'),
    );

    final DriveSpikePhotoData response = await service.getPhoto(
      requestId: 'request-get',
      clientVersion: 'v0.5.0',
      idToken: 'test-id-token',
      storageFileId: 'drive-file-id',
    );

    expect(sentBody['action'], 'getSpikePhoto');
    expect(sentBody['idToken'], 'test-id-token');
    expect(
      (sentBody['payload'] as Map<String, dynamic>)['storageFileId'],
      'drive-file-id',
    );
    expect(response.bytes, imageBytes);

    service.close();
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
