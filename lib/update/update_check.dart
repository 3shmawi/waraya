import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../level/lang.dart';
import '../version.dart';
import 'play_update.dart';

/// What `latest.json` says — the newest copy of the game, and what is new
/// in it.
///
/// One file, written by the workflows from the same places the stores read:
/// the version from `pubspec.yaml`, the notes from
/// `fastlane/release_notes/{ar,en}.txt`. `pages.yml` puts one next to the web
/// game (with the commit it was built from), `release.yml` attaches one to
/// every release.
@immutable
class Published {
  const Published({
    required this.version,
    this.build = '',
    this.buildNumber = 0,
    this.notesAr = '',
    this.notesEn = '',
    this.changes = const [],
    this.minVersion = '',
  });

  final String version;

  /// The oldest version still allowed to play, or empty for none. A copy
  /// older than this gets an update it cannot wave away: for the day a
  /// server or level change leaves old builds broken, not for every release.
  final String minVersion;

  /// The commit the web game was built from. Empty on a release's copy.
  final String build;

  /// The release's build number, or 0.
  final int buildNumber;

  final String notesAr;
  final String notesEn;

  /// The last commits, newest first: `(sha, subject)`.
  final List<(String, String)> changes;

  /// What changed since [build] — the commits above it — as lines to show.
  /// Empty when [build] is not among them (too old, or unknown).
  List<String> changesSince(String build) {
    final at = changes.indexWhere((change) => change.$1 == build);
    if (at <= 0) return const [];
    return [for (final (_, subject) in changes.take(at).take(5)) '• $subject'];
  }

  String notesIn(Lang lang) =>
      lang == Lang.en && notesEn.isNotEmpty ? notesEn : notesAr;

  /// Reads the file. Null for anything that is not one: a missing field is
  /// a file from somewhere else, and a wrong answer here is a nag.
  static Published? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    if (version is! String || parseVersion(version) == null) return null;
    final notes = json['notes'];
    String note(String lang) => notes is Map && notes[lang] is String
        ? (notes[lang] as String).trim()
        : '';
    final build = json['build'];
    final number = json['buildNumber'];
    final changes = json['changes'];
    final minimum = json['minVersion'];
    return Published(
      minVersion: minimum is String && parseVersion(minimum) != null
          ? minimum
          : '',
      version: version,
      build: build is String ? build : '',
      buildNumber: number is int ? number : 0,
      notesAr: note('ar'),
      notesEn: note('en'),
      changes: [
        if (changes is List)
          for (final change in changes)
            if (change is Map &&
                change['sha'] is String &&
                change['subject'] is String)
              (change['sha'] as String, change['subject'] as String),
      ],
    );
  }
}

/// How an update reaches this copy.
enum UpdateRoute {
  /// The web: the new game is already on the server, a reload fetches it.
  reload,

  /// An installed build: the new one has to be downloaded.
  download,

  /// A build from a store: the store updates it, so the button opens the
  /// game's page there.
  store,
}

/// The version the App Store is serving, from its public lookup's answer
/// (`itunes.apple.com/lookup?bundleId=…`), or null for none.
String? appStoreVersion(Object? json) {
  if (json is! Map) return null;
  final results = json['results'];
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  if (first is! Map) return null;
  final version = first['version'];
  return version is String && parseVersion(version) != null ? version : null;
}

/// An update this copy of the game does not have.
@immutable
class Update {
  const Update({
    required this.published,
    required this.route,
    this.running = appVersion,
    this.runningBuild = appBuild,
    this.page,
    this.fromStore = false,
  });

  final Published published;

  /// The store said it has a newer build: an update even when which version
  /// it is is not known (Play names a build by its number only).
  final bool fromStore;
  final UpdateRoute route;

  /// Where taking it goes: the store's page, or the release's. Null on the
  /// web, where taking it is a reload.
  final Uri? page;

  /// The version it was compared against: this copy's.
  final String running;

  /// The web build it was compared against: this copy's commit.
  final String runningBuild;

  /// What to tell the player is in it, in [lang].
  ///
  /// A new version has its notes. A new web build of the same version has
  /// the commits since the one on screen, when the file still lists it.
  /// Anything else has no notes of its own and says nothing.
  String notesIn(Lang lang) {
    if (isNewVersion) return published.notesIn(lang);
    return published.changesSince(runningBuild).join('\n');
  }

  /// Whether the version number moved, or only the web build under it — a
  /// push between versions. The second still deserves a reload, but has no
  /// notes of its own to show.
  bool get isNewVersion =>
      fromStore || compareVersions(published.version, running) > 0;

  /// Whether this copy is older than the oldest one allowed to play: the
  /// update cannot be waved away.
  bool get isForced =>
      published.minVersion.isNotEmpty &&
      compareVersions(running, published.minVersion) < 0;
}

/// `[major, minor, patch]`, or null for anything else.
List<int>? parseVersion(String text) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(text.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

/// Negative, zero or positive, like `compareTo`. Unparseable is oldest.
int compareVersions(String a, String b) {
  final x = parseVersion(a);
  final y = parseVersion(b);
  if (x == null || y == null) return x == null ? (y == null ? 0 : -1) : 1;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return 0;
}

/// Asks whether there is a newer game than this one.
///
/// Silent on every failure — offline, a server having a bad day, a file
/// that does not parse: the answer is "no update", and the player hears
/// nothing. A nag that fires on a network error is worse than none.
class UpdateChecker {
  UpdateChecker({
    required this.source,
    required this.route,
    this.page,
    this.storeGate = const [],
    this.play,
    this.running = appVersion,
    this.runningBuild = appBuild,
    this.runningNumber = appBuildNumber,
    Future<String> Function(Uri uri)? fetch,
  }) : _fetch = fetch ?? _get;

  /// Where `latest.json` is read from. Null checks nothing.
  final Uri? source;
  final UpdateRoute route;

  /// Where taking the update goes. See [Update.page].
  final Uri? page;

  /// The App Store's own answer to «which version are you serving», tried
  /// in order until one knows the game. `latest.json` is attached to the
  /// release the moment it is built, days before Apple has reviewed it; an
  /// iPhone told then would open the store and find nothing new. So on the
  /// iPhone the store says when, and `latest.json` says what is in it.
  final List<Uri> storeGate;

  /// On Android: Play's own answer, the same job as [storeGate] on the
  /// iPhone ([askPlay]). Null when it cannot say — a copy Play did not
  /// install — and then this is a downloaded APK, told about the release
  /// and sent to its page.
  final Future<PlayServing?> Function()? play;
  final String running;
  final String runningBuild;
  final int runningNumber;
  final Future<String> Function(Uri uri) _fetch;

  /// The web game's file, next to it on the site. Relative, so it is right
  /// on GitHub Pages under /waraya/ and on Cloudflare at the root alike.
  static Uri webSource(Uri page) => page.resolve('../latest.json');

  /// The newest release's file, for a build installed from a release.
  static final Uri releaseSource = Uri.parse(
    'https://github.com/3shmawi/waraya/releases/latest/download/latest.json',
  );

  /// Where a download goes.
  static final Uri releasePage = Uri.parse(
    'https://github.com/3shmawi/waraya/releases/latest',
  );

  /// The game on each store — the same links as `site/get/index.html`.
  static final Uri appStorePage = Uri.parse(
    'https://apps.apple.com/app/id6818521154',
  );
  static final Uri playPage = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.mohager.waraya',
  );

  /// The App Store's lookup for the game: Egypt's storefront first, where
  /// it is surely sold, then the default.
  static final List<Uri> appStoreLookup = [
    for (final country in ['eg', ''])
      Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': 'com.mohager.waraya',
        if (country.isNotEmpty) 'country': country,
      }),
  ];

  /// The update, or null for none (or for not knowing).
  Future<Update?> check() async {
    final from = source;
    if (from == null) return null;
    try {
      // A query that changes, so neither the browser nor a CDN answers from
      // a copy made before the update existed.
      final fresh = from.replace(
        queryParameters: {
          ...from.queryParameters,
          't': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}',
        },
      );
      var published = Published.fromJson(jsonDecode(await _fetch(fresh)));
      if (published == null) return null;
      final asked = play;
      if (asked != null) {
        final serving = await asked();
        if (serving != null) return _fromPlay(published, serving);
        return _compare(
          published,
          route: UpdateRoute.download,
          page: UpdateChecker.releasePage,
        );
      }
      if (storeGate.isNotEmpty) {
        final serving = await _storeVersion();
        if (serving == null) return null;
        // Behind the release (still in review): what the store has is the
        // update, and the release's notes are not its notes.
        if (compareVersions(serving, published.version) < 0) {
          published = Published(
            version: serving,
            minVersion: published.minVersion,
          );
        }
        final order = compareVersions(published.version, running);
        final forced =
            published.minVersion.isNotEmpty &&
            compareVersions(running, published.minVersion) < 0 &&
            compareVersions(published.version, published.minVersion) >= 0;
        if (order <= 0 && !forced) return null;
        return Update(
          published: published,
          route: route,
          running: running,
          runningBuild: runningBuild,
          page: page,
        );
      }
      return _compare(published, route: route, page: page);
    } catch (_) {
      return null;
    }
  }

  /// What Play has, told with the release's notes when it is the release.
  Update? _fromPlay(Published published, PlayServing serving) {
    if (!serving.newer) return null;
    final current =
        published.buildNumber > 0 &&
        serving.versionCode >= published.buildNumber;
    final shown = current
        ? published
        // Play is behind the release, or cannot say which build it has:
        // there is an update, but not one whose notes are known.
        : const Published(version: '');
    return Update(
      published: shown,
      route: route,
      running: running,
      runningBuild: runningBuild,
      page: page,
      fromStore: true,
    );
  }

  /// The release against this copy: a newer version, a rebuild, or a
  /// version too old to play.
  Update? _compare(
    Published published, {
    required UpdateRoute route,
    Uri? page,
  }) {
    final order = compareVersions(published.version, running);
    // Same version, later build: a rebuild that went out with fixes. Only
    // a build that knows its own number can tell; one made at a desk is 0.
    final newer =
        order > 0 ||
        (order == 0 &&
            runningNumber > 0 &&
            published.buildNumber > runningNumber);
    // On the web the page itself is what changed, version or not. Only a
    // build that knows its own commit can tell — a local run does not.
    final rebuilt =
        route == UpdateRoute.reload &&
        runningBuild.isNotEmpty &&
        published.build.isNotEmpty &&
        published.build != runningBuild;
    final forced =
        published.minVersion.isNotEmpty &&
        compareVersions(running, published.minVersion) < 0;
    if (!newer && !rebuilt && !forced) return null;
    return Update(
      published: published,
      route: route,
      running: running,
      runningBuild: runningBuild,
      page: page,
    );
  }

  Future<String?> _storeVersion() async {
    for (final uri in storeGate) {
      try {
        final version = appStoreVersion(jsonDecode(await _fetch(uri)));
        if (version != null) return version;
      } catch (_) {
        // The next storefront, or silence.
      }
    }
    return null;
  }

  static Future<String> _get(Uri uri) async {
    final response = await http
        .get(uri, headers: {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException('${response.statusCode}', uri);
    }
    return utf8.decode(response.bodyBytes);
  }
}
