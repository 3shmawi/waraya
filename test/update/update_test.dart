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

  group('a forced update', () {
    String withMinimum(String minimum, {String version = '1.3.0'}) =>
        jsonEncode({'version': version, 'minVersion': minimum});

    test('a copy older than minVersion is forced', () async {
      final update = await checker(() => withMinimum('1.3.0')).check();
      expect(update!.isForced, isTrue);
    });

    test('a copy at or past minVersion is only offered it', () async {
      final update = await checker(() => withMinimum('1.2.0')).check();
      expect(update!.isForced, isFalse);
      expect(
        await checker(() => withMinimum('1.0.0', version: '1.2.0')).check(),
        isNull,
      );
    });

    test('no or a broken minVersion forces nothing', () async {
      expect(
        (await checker(() => file(version: '1.3.0')).check())!.isForced,
        isFalse,
      );
      expect(
        (await checker(() => withMinimum('soon')).check())!.isForced,
        isFalse,
      );
    });
  });

  group('from a store', () {
    // The iPhone: latest.json says what is in it, the App Store says when.
    final release = Uri.parse('https://example.com/latest.json');
    final eg = Uri.parse('https://store.example/lookup?country=eg');
    final anywhere = Uri.parse('https://store.example/lookup');
    String lookup(String? version) => jsonEncode({
      'resultCount': version == null ? 0 : 1,
      'results': [
        if (version != null) {'version': version, 'releaseNotes': 'x'},
      ],
    });

    UpdateChecker iphone(
      Map<Uri, String> answers, {
      String running = '1.0.0',
    }) => UpdateChecker(
      source: release,
      route: UpdateRoute.store,
      page: UpdateChecker.appStorePage,
      storeGate: [eg, anywhere],
      running: running,
      fetch: (uri) async {
        final key = answers.keys.firstWhere(
          (k) =>
              k.host == uri.host &&
                  k.path == uri.path &&
                  k.query == uri.query ||
              (k == release && uri.host == release.host),
          orElse: () => throw StateError('offline'),
        );
        return answers[key]!;
      },
    );

    test('released but still in review: nothing yet', () async {
      final update = await iphone({
        release: file(version: '1.1.0'),
        eg: lookup('1.0.0'),
      }).check();
      expect(update, isNull);
    });

    test('in the store: offered, with its notes, opening the store', () async {
      final update = await iphone({
        release: file(version: '1.1.0'),
        eg: lookup('1.1.0'),
      }).check();
      expect(update, isNotNull);
      expect(update!.published.version, '1.1.0');
      expect(update.notesIn(Lang.en), 'new');
      expect(update.route, UpdateRoute.store);
      expect(update.page, UpdateChecker.appStorePage);
    });

    test('the store behind the release: what the store has, without the '
        'release\'s notes', () async {
      final update = await iphone({
        release: file(version: '1.2.0'),
        eg: lookup('1.1.0'),
      }).check();
      expect(update!.published.version, '1.1.0');
      expect(update.notesIn(Lang.en), isEmpty);
    });

    test('a storefront that does not know it: the next one', () async {
      final update = await iphone({
        release: file(version: '1.1.0'),
        eg: lookup(null),
        anywhere: lookup('1.1.0'),
      }).check();
      expect(update?.published.version, '1.1.0');
    });

    test('no store answer is silence', () async {
      expect(await iphone({release: file(version: '1.1.0')}).check(), isNull);
    });

    test('a rebuild of the same version is not offered', () async {
      expect(
        await iphone({
          release: file(version: '1.1.0'),
          eg: lookup('1.1.0'),
        }, running: '1.1.0').check(),
        isNull,
      );
    });

    test('the lookup is read for its version and nothing else', () {
      expect(appStoreVersion(jsonDecode(lookup('1.1.1'))), '1.1.1');
      expect(appStoreVersion(jsonDecode(lookup(null))), isNull);
      expect(
        appStoreVersion({
          'results': [
            {'version': 'soon'},
          ],
        }),
        isNull,
      );
      expect(appStoreVersion('nope'), isNull);
    });

    test('the iPhone looks in Egypt\'s store first', () {
      expect(UpdateChecker.appStoreLookup.first.queryParameters, {
        'bundleId': 'com.mohager.waraya',
        'country': 'eg',
      });
    });
  });
}

class _Notes extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    utf8.encode(key.endsWith('ar.txt') ? 'ملاحظات' : 'notes'),
  );
}
