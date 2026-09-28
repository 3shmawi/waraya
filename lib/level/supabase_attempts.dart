import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'attempts.dart';
import 'supabase_levels.dart';

/// Sends each attempt to the `attempts` table, and forgets it.
///
/// Fire and forget, on purpose. Nothing is queued, nothing is retried, and a
/// failure goes nowhere: a player offline is a player the numbers do not
/// hear from, which is a smaller loss than a game that stutters to send a
/// statistic, or a phone that saves up a week of them.
///
/// Anonymous. The only thing tying two rows together is [deviceId], a random
/// id this install made up the first time and kept — no account, no name, no
/// address. It exists so "one person restarted forty times" and "forty
/// people restarted once" are different numbers.
class SupabaseAttempts implements AttemptSink {
  SupabaseAttempts(this.deviceId, {Future<void> Function(String body)? post})
    : _post = post ?? _postToSupabase;

  final String deviceId;
  final Future<void> Function(String body) _post;

  /// This install's id: read if there is one, made and kept if not. Never
  /// throws — a store that cannot be read gives an id for this session only.
  static Future<SupabaseAttempts> open() async {
    const key = 'waraya.device';
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(key);
      if (id == null) {
        id = uuid4(Random.secure());
        await prefs.setString(key, id);
      }
      return SupabaseAttempts(id);
    } catch (_) {
      return SupabaseAttempts(uuid4(Random.secure()));
    }
  }

  @override
  void record(Attempt attempt) {
    final body = jsonEncode({...attempt.toJson(), 'device_id': deviceId});
    unawaited(
      _post(body).catchError((Object _) {
        // Nowhere to put it, and nothing the player should hear about.
      }),
    );
  }

  static Future<void> _postToSupabase(String body) async {
    await http
        .post(
          Uri.parse('${SupabaseProject.url}/rest/v1/attempts'),
          headers: {
            'apikey': SupabaseProject.publishableKey,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));
  }
}
