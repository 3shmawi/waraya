/// The game — what every build that does not name a target ships.
///
/// `flutter build apk`, `ios`, `macos`, `windows`, `linux` and `web` all build
/// `lib/main.dart` unless told otherwise, and until Phase 10 this file was the
/// Phase 1 walker: one horizon, nothing to solve. So the default store build
/// was a scenery demo, and nothing failed to say so. The walker lives on as
/// `main_scene.dart`; this is the campaign, and `main_levels.dart` stays the
/// name every script and doc already uses for it.
library;

export 'main_levels.dart' show main;
