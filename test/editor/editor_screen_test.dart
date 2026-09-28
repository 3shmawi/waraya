// The editor on screen: that it opens editing, that the buttons reach the
// model, and that Tab is the whole distance between editing a level and
// playing it — the same game, carrying on.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_game.dart';
import 'package:waraya/editor/editor_screen.dart';
import 'package:flame/game.dart';
import 'package:waraya/level/levels.dart';

/// A game never settles — it asks for the next frame for ever — so this is
/// "long enough for a menu to open or close".
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Future<EditorGame> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: EditorScreen(startFrom: Levels.pressItEarly)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final widget = tester.widget<GameWidget<EditorGame>>(
      find.byType(GameWidget<EditorGame>),
    );
    return widget.game!;
  }

  testWidgets('opens editing, with the level and its runs in the panel', (
    tester,
  ) async {
    final game = await open(tester);
    expect(game.mode, EditorMode.editing);
    expect(find.text('the level'), findsOneWidget);
    expect(find.textContaining('solution ·'), findsOneWidget);
    expect(find.textContaining('wrong idea 1'), findsOneWidget);
    // Let the gate's replays run, then read what it said.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('the gate'), findsOneWidget);
    // This level's lesson is a cheap run, and outside the campaign that is a
    // refusal — so the panel names it.
    expect(
      find.textContaining('finished without being played'),
      findsOneWidget,
    );
  });

  testWidgets('a button adds a piece and selects it', (tester) async {
    await open(tester);
    await tester.tap(find.text('+ door'));
    await tester.pump();
    expect(find.text('door'), findsWidgets);
    expect(find.text('stays open after, seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Tab plays it and Tab brings you back', (tester) async {
    final game = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.mode, EditorMode.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.mode, EditorMode.editing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    '"start from" opens a blank level, and a campaign one as a copy',
    (tester) async {
      final game = await open(tester);
      await tester.tap(find.byTooltip('start from…'));
      await settle(tester);
      await tester.tap(find.text('a blank level'));
      await settle(tester);
      expect(game.level.id, 'new-level');

      await tester.tap(find.byTooltip('start from…'));
      await settle(tester);
      await tester.tap(find.textContaining('two-not-one'));
      await settle(tester);
      expect(game.level.id, 'two-not-one-copy');
      expect(game.level.delays, Levels.twoNotOne.delays);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
