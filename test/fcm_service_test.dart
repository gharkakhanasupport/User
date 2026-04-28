import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ghar_ka_khana/services/fcm_service.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String tempDir;

  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getTemporaryPath() async {
    return tempDir;
  }
}

void main() {
  group('FCM Service - downloadImageStaticForTesting', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gkk_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('downloads image and returns path on success (200 OK)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/image.jpg') {
          return http.Response.bytes([1, 2, 3, 4], 200);
        }
        return http.Response('Not found', 404);
      });

      final result = await downloadImageStaticForTesting(
        'https://example.com/image.jpg',
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result, startsWith(tempDir.path));

      final file = File(result!);
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), equals([1, 2, 3, 4]));
    });

    test('returns null when URL is invalid', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes([1, 2, 3], 200);
      });

      final result = await downloadImageStaticForTesting(
        'not a valid url',
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('returns null when response is 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final result = await downloadImageStaticForTesting(
        'https://example.com/image.jpg',
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('returns null when response bytes are empty', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes([], 200);
      });

      final result = await downloadImageStaticForTesting(
        'https://example.com/image.jpg',
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('returns null on timeout/exception', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Simulated network error');
      });

      final result = await downloadImageStaticForTesting(
        'https://example.com/image.jpg',
        client: mockClient,
      );

      expect(result, isNull);
    });
  });
}
