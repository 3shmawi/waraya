import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../level/lang.dart';
import '../version.dart';

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
    this.notesAr = '',
    this.notesEn = '',
  });

  final String version;

  /// The commit the web game was built from. Empty on a release's copy.
  final String build;

  final String notesAr;
  final String notesEn;

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
    return Published(
      version: version,
      build: build is String ? build : '',
      notesAr: note('ar'),
      notesEn: note('en'),
    );
  }
}

/// How an update reaches this copy.
enum UpdateRoute {
  /// The web: the new game is already on the server, a reload fetches it.
  reload,

  /// An installed build: the new one has to be downloaded.
  download,
}

/// An update this copy of the game does not have.
@immutable
class Update {
  const Update({
    required this.published,
    required this.route,
    this.running = appVersion,
  });

  final Published published;
  final UpdateRoute route;

  /// The version it was compared against: this copy's.
  final String running;

  /// Whether the version number moved, or only the web build under it — a
  /// push between versions. The second still deserves a reload, but has no
  /// notes of its own to show.
  bool get isNewVersion => compareVersions(published.version, running) > 0;
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
    this.running = appVersion,
    this.runningBuild = appBuild,
    Future<String> Function(Uri uri)? fetch,
  }) : _fetch = fetch ?? _get;

  /// Where `latest.json` is read from. Null checks nothing.
  final Uri? source;
  final UpdateRoute route;
  final String running;
  final String runningBuild;
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
      final published = Published.fromJson(jsonDecode(await _fetch(fresh)));
      if (published == null) return null;
      final newer = compareVersions(published.version, running) > 0;
      // On the web the page itself is what changed, version or not. Only a
      // build that knows its own commit can tell — a local run does not.
      final rebuilt =
          route == UpdateRoute.reload &&
          runningBuild.isNotEmpty &&
          published.build.isNotEmpty &&
          published.build != runningBuild;
      if (!newer && !rebuilt) return null;
      return Update(published: published, route: route, running: running);
    } catch (_) {
      return null;
    }
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
