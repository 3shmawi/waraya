import 'gate.dart';
import 'level.dart';

/// What sending a level off needs from a server. One real one
/// (`SupabaseBackend`, in `supabase_backend.dart`) and whatever the tests
/// hand in.
abstract interface class LevelBackend {
  /// Who is signed in, or null. An email, for showing.
  String? get signedInAs;

  /// Signs in with an email and a password.
  ///
  /// A password rather than an emailed link or code, because both of those
  /// need an email Supabase will only let you change with your own SMTP
  /// server — and the link would have to come back into the app, which is a
  /// deep link on every platform. The one author there is makes their account
  /// once in the dashboard (Authentication → Users → Add user), and the bench
  /// keeps the session after that.
  Future<void> signIn(String email, String password);

  /// Puts the level in the table as `pending`, or puts an author's own
  /// earlier submission back to `pending` with new data. Throws
  /// [UploadRefused] when the id belongs to somebody else or is already
  /// published.
  Future<void> submit(String id, Map<String, Object?> data);
}

/// The server said no, for a reason worth showing as it is.
class UploadRefused implements Exception {
  UploadRefused(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where an attempt to send a level got to.
sealed class UploadResult {
  const UploadResult();
}

/// The gate would refuse it, so it was not sent. [reasons] are the gate's
/// own words.
class RefusedHere extends UploadResult {
  const RefusedHere(this.reasons);
  final String reasons;
}

/// It would pass, and there is nobody signed in to send it as.
class NeedsSignIn extends UploadResult {
  const NeedsSignIn();
}

/// It is in the table, waiting for the gate.
class Submitted extends UploadResult {
  const Submitted(this.id);
  final String id;
}

/// Something between here and the server went wrong.
class Failed extends UploadResult {
  const Failed(this.message);
  final String message;
}

/// Sends a level to be judged — after judging it here first.
///
/// The local check is [judgeRows], the gate's own function, on the exact row
/// that would be sent. So "the workshop said yes and the gate said no" can
/// only mean the two ran different builds, never that they asked different
/// questions. It is not a gate — anyone can put a row in the table without
/// this app — it is the author finding out in a second instead of an hour.
class LevelUpload {
  LevelUpload(this.backend);

  final LevelBackend backend;

  Future<UploadResult> send(Level level) async {
    final data = level.toJson();
    final [decision] = await judgeRows([
      {'id': level.id, 'data': data},
    ]);
    if (decision.status != 'published') {
      return RefusedHere(decision.verdict ?? 'refused');
    }
    if (backend.signedInAs == null) return const NeedsSignIn();
    try {
      await backend.submit(level.id, data);
      return Submitted(level.id);
    } on UploadRefused catch (error) {
      return Failed(error.message);
    } catch (error) {
      return Failed('$error');
    }
  }
}
