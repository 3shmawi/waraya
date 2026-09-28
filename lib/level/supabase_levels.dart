import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'level.dart';
import 'level_check.dart';
import 'level_source.dart';

/// The project's Supabase. Both values are public by design — the publishable
/// key (what used to be called the anon key) is what every copy of the app
/// ships with, and what protects the table is its
/// row-level security (`supabase/migrations/`), not the key. The service key
/// is the one that is not, and it lives in GitHub secrets and nowhere else.
abstract final class SupabaseProject {
  static const String url = 'https://anuohrvxlmthfvbnukrb.supabase.co';
  static const String publishableKey =
      'sb_publishable_cp6qBlCGVyr2M1EO8wGlsw_MiXufFGT';
}

/// Fetches the body of the published-levels query. A seam so the tests can
/// hand in a server that answers, one that fails, and one that hangs.
typedef FetchLevels = Future<String> Function();

/// Where the last good answer is kept, for the day the server is not there.
abstract interface class LevelCache {
  Future<String?> read();
  Future<void> write(String body);
}

/// Levels someone else wrote, published through the gate.
///
/// Only ever the *second* half of `LevelsThenExtras(BuiltInLevels(), …)`: the
/// campaign ships in the app and works in an aeroplane, and this can add to
/// it and nothing more. Everything that can go wrong here is quiet — the
/// player gets the campaign and no message.
///
/// **And it trusts the server with nothing.** The gate should only ever have
/// published a level that passed `checkLevel`, but the gate ran on whatever
/// build it was, and this is whatever build *this* is. So every level is
/// checked again, here, by the game that is about to play it: a level this
/// build cannot play is refused by `requires`, and one whose recordings do
/// not replay on this build's physics is refused by replaying them. A level
/// the gate got wrong costs a level, never a broken one on screen.
class SupabaseLevels implements LevelSource {
  SupabaseLevels({
    FetchLevels? fetch,
    this.cache,
    this.timeout = const Duration(seconds: 4),
    this.onRefused,
  }) : fetch = fetch ?? fetchPublished;

  final FetchLevels fetch;
  final LevelCache? cache;

  /// How long the player's game waits before deciding the server is not there.
  final Duration timeout;

  /// Told about each level this build would not play, and why. The player is
  /// not; a debug build can shout through this.
  final void Function(Verdict verdict)? onRefused;

  @override
  String get label => 'supabase';

  @override
  Future<List<Level>> load() async {
    String body;
    try {
      body = await fetch().timeout(timeout);
      // Only a body that reads is worth keeping in place of the last one.
      _rows(body);
      unawaited(_remember(body));
    } catch (error) {
      final kept = await _recall();
      if (kept == null) rethrow;
      body = kept;
    }

    final levels = <Level>[];
    for (final row in _rows(body)) {
      final verdict = await checkLevelJson(row);
      if (verdict.accepted) {
        levels.add(levelFromJson(row));
      } else {
        onRefused?.call(verdict);
      }
    }
    return levels;
  }

  Future<void> _remember(String body) async {
    try {
      await cache?.write(body);
    } catch (_) {
      // A cache that cannot be written is a cache that is empty next time.
    }
  }

  Future<String?> _recall() async {
    try {
      return await cache?.read();
    } catch (_) {
      return null;
    }
  }

  /// The level data out of each row. The query asks for `data` only, so a
  /// row is `{"data": {...}}`.
  static List<Object?> _rows(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw LevelFormatException('supabase did not answer with a list');
    }
    return [for (final row in decoded) row is Map ? row['data'] : row];
  }

  /// The published levels, in the order they were given, through PostgREST.
  ///
  /// Plain HTTP rather than the Supabase client: reading one public table is
  /// one GET, and the client — with its auth and its realtime — earns its
  /// weight when there is signing in to do, which is uploading (8.3), not
  /// playing.
  static Future<String> fetchPublished() async {
    final uri = Uri.parse('${SupabaseProject.url}/rest/v1/levels').replace(
      queryParameters: {
        'select': 'data',
        'status': 'eq.published',
        'order': 'sort_order.asc,created_at.asc',
      },
    );
    final response = await http.get(
      uri,
      headers: {'apikey': SupabaseProject.publishableKey},
    );
    if (response.statusCode != 200) {
      throw http.ClientException('levels: HTTP ${response.statusCode}', uri);
    }
    return utf8.decode(response.bodyBytes);
  }
}

/// The last good answer, in the same store progress is kept in.
class StoredLevelCache implements LevelCache {
  const StoredLevelCache();

  static const String _key = 'waraya.published-levels';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String body) async =>
      (await SharedPreferences.getInstance()).setString(_key, body);
}
