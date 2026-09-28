import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/main.dart' as default_target;
import 'package:waraya/main_levels.dart' as campaign;

/// `lib/main.dart` is what every build without `-t` ships — `flutter build
/// apk`, `ipa`, `macos`, `windows`, `linux`, `web` — and for nine phases it
/// was the Phase 1 walker. Nothing failed: it built, it ran, it drew a lovely
/// horizon with no puzzle in it. So this says it out loud.
void main() {
  test('the default build target is the campaign', () {
    expect(identical(default_target.main, campaign.main), isTrue);
  });
}
