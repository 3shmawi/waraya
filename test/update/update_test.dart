import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/update/update_check.dart';
import 'package:waraya/update/whats_new.dart';
import 'package:waraya/version.dart';

/// Hearing about a newer game (lib/update/).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String file({String version = '9.9.9', String build = 'new'}) => jsonEncode({
    'version': version,
    'build': build,
    'notes': {'ar': 'جديد', 'en': 'new'},
  });

  UpdateChecker checker(
    String Function() answer, {
    UpdateRoute route = UpdateRoute.download,
    String running = '1.2.0',
    String runningBuild = '',
  }) => UpdateChecker(
    source: Uri.parse('https://example.com/latest.json'),
    route: route,
    running: running,
    runningBuild: runningBuild,
    fetch: (_) async => answer(),
  );

  group('versions', () {
    test('compare as numbers, not as text', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('v2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('nonsense', '1.0.0'), lessThan(0));
    });
  });

  group('the checker', () {
    test('a newer version is an update, with its notes', () async {
      final update = await checker(() => file(version: '1.3.0')).check();
      expect(update, isNotNull);
      expect(update!.isNewVersion, isTrue);
      expect(update.published.notesIn(Lang.en), 'new');
      expect(update.published.notesIn(Lang.ar), 'جديد');
    });

    test('the same or an older version is nothing', () async {
      expect(await checker(() => file(version: '1.2.0')).check(), isNull);
      expect(await checker(() => file(version: '1.1.9')).check(), isNull);
    });

    test('on the web, a new build of the same version is a reload', () async {
      final update = await checker(
        () => file(version: '1.2.0', build: 'b'),
        route: UpdateRoute.reload,
        runningBuild: 'a',
      ).check();
      expect(update, isNotNull);
      expect(update!.isNewVersion, isFalse, reason: 'no notes of its own');
    });

    test(
      'a build that does not know its commit never nags about one',
      () async {
        // A local run: the file's commit always differs from nothing.
        expect(
          await checker(
            () => file(version: '1.2.0', build: 'b'),
            route: UpdateRoute.reload,
          ).check(),
          isNull,
        );
      },
    );

    test('the same version with a later build number is an update', () async {
      String numbered(int n) =>
          jsonEncode({'version': '1.2.0', 'buildNumber': n, 'notes': {}});
      UpdateChecker at(int running, int published) => UpdateChecker(
        source: Uri.parse('https://example.com/latest.json'),
        route: UpdateRoute.download,
        running: '1.2.0',
        runningNumber: running,
        fetch: (_) async => numbered(published),
      );
      expect(await at(40, 41).check(), isNotNull);
      expect(await at(41, 41).check(), isNull);
      expect(await at(42, 41).check(), isNull);
      // Made at a desk, it knows no number, and is never nagged by one.
      expect(await at(0, 41).check(), isNull);
    });

    test('a new web build says which commits came with it', () async {
      final update = await checker(
        () => jsonEncode({
          'version': '1.2.0',
          'build': 'c3',
          'changes': [
            {'sha': 'c3', 'subject': 'A fixed walk pad'},
            {'sha': 'c2', 'subject': 'One crouch'},
            {'sha': 'c1', 'subject': 'Already here'},
          ],
        }),
        route: UpdateRoute.reload,
        runningBuild: 'c1',
      ).check();
      expect(update!.notesIn(Lang.en), '• A fixed walk pad\n• One crouch');
    });

    test('and nothing invented when its own commit is not listed', () async {
      final update = await checker(
        () => jsonEncode({
          'version': '1.2.0',
          'build': 'c3',
          'changes': [
            {'sha': 'c3', 'subject': 'Something'},
          ],
        }),
        route: UpdateRoute.reload,
        runningBuild: 'ancient',
      ).check();
      expect(update!.notesIn(Lang.en), isEmpty);
    });

    test('every failure is silence', () async {
      expect(
        await checker(() => throw const SocketException('x')).check(),
        isNull,
      );
      expect(await checker(() => 'not json').check(), isNull);
      expect(await checker(() => '{"version": "soon"}').check(), isNull);
      expect(
        await UpdateChecker(source: null, route: UpdateRoute.download).check(),
        isNull,
      );
    });

    test('the web reads the file next to the game, wherever it is served', () {
      expect(
        UpdateChecker.webSource(
          Uri.parse('https://3shmawi.github.io/waraya/play/'),
        ).toString(),
        'https://3shmawi.github.io/waraya/latest.json',
      );
      expect(
        UpdateChecker.webSource(
          Uri.parse('https://waraya.pages.dev/play/'),
        ).toString(),
        'https://waraya.pages.dev/latest.json',
      );
    });
  });

  group('what is new', () {
    final bundle = _Notes();

    test('a first-time player is not told what changed', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await WhatsNew.takeOnce(playedBefore: false, bundle: bundle),
        isNull,
      );
    });

    test('a returning player is told once', () async {
      SharedPreferences.setMockInitialValues({'waraya.seenVersion': '0.9.0'});
      final first = await WhatsNew.takeOnce(playedBefore: true, bundle: bundle);
      expect(first?.version, appVersion);
      expect(first?.notesAr, 'ملاحظات');
      expect(
        await WhatsNew.takeOnce(playedBefore: true, bundle: bundle),
        isNull,
        reason: 'once',
      );
    });

    test('somebody who played before this existed is told too', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await WhatsNew.takeOnce(playedBefore: true, bundle: bundle),
        isNotNull,
      );
    });

    test('the notes shipped are the stores\' own files', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- fastlane/release_notes/ar.txt'));
      expect(pubspec, contains('- fastlane/release_notes/en.txt'));
    });
  });
}

class _Notes extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    utf8.encode(key.endsWith('ar.txt') ? 'ملاحظات' : 'notes'),
  );
}
