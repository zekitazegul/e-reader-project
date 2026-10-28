import 'dart:convert';

import 'package:e_reader/app_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> release({
  String version = 'v1.0.0+22',
  String host = 'github.com',
  bool preview = false,
}) => {
  'tag_name': version,
  'draft': false,
  'prerelease': preview,
  'assets': [
    {
      'name': 'app-arm64-v8a-release.apk',
      'state': 'uploaded',
      'browser_download_url':
          'https://$host/$updateRepository/releases/download/$version/arm64.apk',
    },
    {
      'name': 'E-Reader-Installer.apk',
      'state': 'uploaded',
      'browser_download_url':
          'https://$host/$updateRepository/releases/download/$version/E-Reader-Installer.apk',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Latest stable release uses a trusted universal APK and compares build numbers', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/repos/$updateRepository/releases/latest');
      return http.Response(jsonEncode(release()), 200);
    });
    addTearDown(client.close);
    final latest = (await latestAppRelease(client))!;
    expect(latest.apk.path, endsWith('/E-Reader-Installer.apk'));
    expect(latest.isNewerThan('1.0.0', 21), isTrue);
    expect(latest.isNewerThan('1.0.0', 22), isFalse);
    expect(latest.isNewerThan('1.0.0', 23), isFalse);
    expect(AppRelease('v1.2.0', latest.apk).isNewerThan('1.1.9', 99), isTrue);
  });

  test('No release is handled; preview, untrusted URL and service failures are rejected', () async {
    final none = MockClient((_) async => http.Response('{}', 404));
    final preview = MockClient(
      (_) async => http.Response(jsonEncode(release(preview: true)), 200),
    );
    final untrusted = MockClient(
      (_) async => http.Response(jsonEncode(release(host: 'example.com')), 200),
    );
    final failure = MockClient((_) async => http.Response('{}', 403));
    addTearDown(() {
      none.close();
      preview.close();
      untrusted.close();
      failure.close();
    });
    expect(await latestAppRelease(none), isNull);
    expect(await latestAppRelease(preview), isNull);
    await expectLater(latestAppRelease(untrusted), throwsFormatException);
    await expectLater(latestAppRelease(failure), throwsFormatException);
  });

  testWidgets(
    'Update starts direct Android download without opening a browser',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('e_reader/chrome'),
        (call) async {
          calls.add(call);
          if (call.method == 'appVersion') {
            return {'version': '1.0.0', 'build': 21};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('e_reader/chrome'),
          null,
        ),
      );
      final client = MockClient(
        (_) async => http.Response(jsonEncode(release()), 200),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(home: AppUpdateDialog(client: client)),
      );
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['appVersion']);
      await tester.tap(find.text('Güncelle'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), [
        'appVersion',
        'downloadUpdate',
      ]);
      expect(
        (calls.last.arguments as Map)['url'],
        contains('/E-Reader-Installer.apk'),
      );
      expect(find.textContaining('Güncelleme indiriliyor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('No published release does not start a download or browser', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('e_reader/chrome'),
      (call) async {
        calls.add(call.method);
        return {'version': '1.0.0', 'build': 21};
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('e_reader/chrome'),
        null,
      ),
    );
    final client = MockClient((_) async => http.Response('{}', 404));
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home: AppUpdateDialog(client: client)));
    await tester.pumpAndSettle();
    expect(calls, ['appVersion']);
    expect(
      find.text('Henüz indirilebilir yeni sürüm yayımlanmadı.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Startup notice checks silently and only downloads after Update is tapped',
    (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('e_reader/chrome'),
        (call) async {
          calls.add(call.method);
          if (call.method == 'appVersion') {
            return {'version': '1.0.0', 'build': 21};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('e_reader/chrome'),
          null,
        ),
      );
      final client = MockClient(
        (_) async => http.Response(jsonEncode(release()), 200),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Reading stays available'),
            bottomSheet: AppUpdateBanner(client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reading stays available'), findsOneWidget);
      expect(find.text('Yeni sürüm hazır: v1.0.0+22'), findsOneWidget);
      expect(calls, ['appVersion']);
      await tester.tap(find.text('Güncelle'));
      await tester.pumpAndSettle();
      expect(calls, ['appVersion', 'downloadUpdate']);
      expect(find.textContaining('Güncelleme indiriliyor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
