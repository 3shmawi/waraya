import 'package:supabase_flutter/supabase_flutter.dart';

import 'level_upload.dart';
import 'supabase_levels.dart';

/// [LevelBackend] on the project's Supabase.
///
/// Only the bench uses this. The game reads published levels with a plain
/// GET (`SupabaseLevels`) and never signs in: an account is for sending a
/// level, never for playing one.
class SupabaseBackend implements LevelBackend {
  SupabaseBackend._(this._client);

  final SupabaseClient _client;

  /// Starts the client once. Safe to await before `runApp`: it reads a stored
  /// session and nothing more, so it works offline.
  static Future<SupabaseBackend> start() async {
    await Supabase.initialize(
      url: SupabaseProject.url,
      publishableKey: SupabaseProject.publishableKey,
    );
    return SupabaseBackend._(Supabase.instance.client);
  }

  @override
  String? get signedInAs => _client.auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> submit(String id, Map<String, Object?> data) async {
    final author = _client.auth.currentUser!.id;
    try {
      await _client.from('levels').insert({
        'id': id,
        'data': data,
        'author': author,
        'status': 'pending',
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // Already there. Row-level security lets an author put their own
      // pending or rejected level back in the queue, and nothing else — so no
      // row back means it is somebody else's, or it is already published.
      final updated = await _client
          .from('levels')
          .update({'data': data, 'status': 'pending', 'verdict': null})
          .eq('id', id)
          .select('id');
      if (updated.isEmpty) {
        throw UploadRefused(
          '"$id" is taken — by another author, or by a level of yours that '
          'is already published. Give it a new id.',
        );
      }
    }
  }
}
