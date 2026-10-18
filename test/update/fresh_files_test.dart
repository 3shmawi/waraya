import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/ui/update_card.dart';
import 'package:waraya/update/fresh_files.dart';
import 'package:waraya/update/update_check.dart';

/// Taking an update on the web fetches the game's files again before the
/// reload, or the reload runs the old game from the browser's cache.
void main() {
  const site = 'https://3shmawi.github.io';

  group('which files', () {
    test('every file the page loaded from its own site', () {
      expect(
        filesToRefresh([
          '$site/waraya/play/main.dart.mjs',
          '$site/waraya/play/main.dart.wasm',
          '$site/waraya/play/assets/AssetManifest.bin',
        ], origin: site),
        [
          '$site/waraya/play/main.dart.mjs',
          '$site/waraya/play/main.dart.wasm',
          '$site/waraya/play/assets/AssetManifest.bin',
        ],
      );
    });

    test('nothing from anywhere else', () {
      expect(
        filesToRefresh([
          'https://fonts.gstatic.com/s/cairo.woff2',
          'https://example.supabase.co/rest/v1/levels',
          'not a url at all',
        ], origin: site),
        isEmpty,
      );
    });

    test('once each, without the #', () {
      expect(
        filesToRefresh([
          '$site/waraya/play/main.dart.wasm',
          '$site/waraya/play/main.dart.wasm#x',
          '$site/waraya/play/main.dart.wasm',
        ], origin: site),
        ['$site/waraya/play/main.dart.wasm'],
      );
    });
  });

  group('the card while it does', () {
    var taken = 0;
    Widget card({required bool taking}) => UpdateCard.update(
      lang: Lang.ar,
      update: Update(
        published: const Published(version: '2.0.0'),
        route: UpdateRoute.reload,
        running: '1.0.0',
      ),
      onTake: () => taken++,
      onLater: () {},
      taking: taking,
    );

    testWidgets('says so, and a second tap does nothing', (tester) async {
      taken = 0;
      await tester.pumpWidget(card(taking: true));
      expect(find.text('بيحدّث…'), findsOneWidget);
      expect(find.text('حدّث'), findsNothing);
      await tester.tap(find.text('بيحدّث…'));
      expect(taken, 0);
    });

    testWidgets('before it starts, the button takes it', (tester) async {
      taken = 0;
      await tester.pumpWidget(card(taking: false));
      await tester.tap(find.text('حدّث'));
      expect(taken, 1);
    });
  });
}
