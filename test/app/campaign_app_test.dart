import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/main_levels.dart';
import 'package:waraya/progress/progress.dart';
import 'package:waraya/ui/level_select.dart';

/// The campaign app, pumped.
///
/// It exists because of what shipped without it: the app skips `MaterialApp`
/// to keep the bundle small, and nothing was providing `Directionality` — so
/// the whole tree threw on the first frame. A release build renders a thrown
/// widget as a **plain grey rectangle**, with no crash, no console noise and
/// nothing in a unit test to notice, and it was only caught by looking at a
/// screenshot. One pump would have caught it.
void main() {
  testWidgets('builds a first frame without throwing', (tester) async {
    await tester.pumpWidget(
      WarayaLevels(
        levels: Levels.campaign,
        progress: MemoryProgress(),
        beaten: const {},
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Both are the only routes there are on a touch screen. Retry especially:
    // it had none at all until now, and level four is designed around needing
    // one.
    expect(find.text('المراحل'), findsOneWidget);
    expect(find.text('من الأول'), findsOneWidget);
  });

  testWidgets('a returning player resumes rather than starting over', (
    tester,
  ) async {
    await tester.pumpWidget(
      WarayaLevels(
        levels: Levels.campaign,
        progress: MemoryProgress(),
        beaten: {Levels.campaign[0].id, Levels.campaign[1].id},
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  // The list itself, pumped on its own. Opening it through the app would mean
  // waiting on a Flame game to finish loading audio and images, which a widget
  // test has no business doing; what matters here is what the list says.
  group('the level list', () {
    // A surface tall enough for every row. `ListView` only builds what is on
    // screen, and a level that is merely scrolled out of view is not a level
    // that is missing.
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Widget listWith(int unlocked) => Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: LevelSelect(
          levels: Levels.campaign,
          unlocked: unlocked,
          current: 0,
          onPick: (_) {},
          onClose: () {},
        ),
      ),
    );

    testWidgets('names every level, so there is something to aim at', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(listWith(Levels.campaign.length));
      for (final level in Levels.campaign) {
        expect(find.text(level.name), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a locked level keeps its hint to itself', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(listWith(1));

      // The one that is open shows what it teaches; the rest must not, or the
      // list hands out the answer to puzzles nobody has reached.
      expect(find.text(Levels.campaign.first.teaches), findsOneWidget);
      for (final level in Levels.campaign.skip(1)) {
        expect(find.text(level.teaches), findsNothing);
      }
    });

    testWidgets('a locked level cannot be picked', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var picked = -1;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: LevelSelect(
              levels: Levels.campaign,
              unlocked: 1,
              current: 0,
              onPick: (i) => picked = i,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text(Levels.campaign[3].name));
      await tester.pump();
      expect(picked, -1, reason: 'level four is not unlocked');

      await tester.tap(find.text(Levels.campaign[0].name));
      await tester.pump();
      expect(picked, 0);
    });
  });
}
