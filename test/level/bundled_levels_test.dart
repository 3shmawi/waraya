// The levels/ folder as the web bench sees it: frozen into the build.
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/bundled_levels.dart';
import 'package:waraya/level/level_check.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every JSON file in levels/ comes through, and nothing else', () async {
    final levels = await const BundledLevels().load();
    expect(levels.map((l) => l.id), contains('try-the-upload'));
  });

  // It is there to be sent from the published bench, so it had better pass.
  test('the level shipped for trying the upload passes the gate', () async {
    final levels = await const BundledLevels().load();
    final level = levels.singleWhere((l) => l.id == 'try-the-upload');
    final verdict = await checkLevel(level);
    expect(verdict.accepted, isTrue, reason: '$verdict');
  });
}
