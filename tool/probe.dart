// Plays a candidate run into a real level and prints where everything was.
//
// Run: flutter test tool/probe.dart
//
// This is the tool for writing a recorded solution, and for fixing one after
// a number moves. A level's `solution` is a list of held inputs with times on
// them, and getting those times right by reasoning about them does not work:
// the shadow's arrival, the door's linger and the arc of a jump all land on
// each other, and the only way to see it is to watch the numbers.
//
// So: put the run in [runs] below, run it, and read the trace. Every tenth of
// a second it prints where the body is, where each shadow is, and how open
// each door is, with a line marking the end of every move. What you are
// usually looking for is the window — the stretch where the shadow is
// standing on the thing — and whether the body gets there inside it.
//
// It is scratch. Nothing imports it and nothing depends on what is in [runs];
// change it freely, and do not bother reverting it.
import 'dart:ui' as ui;

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

/// What to trace. A level and the moves to play into it.
final runs = <(Level, List<Move>)>[
  (Levels.pressItEarly, Levels.pressItEarly.solution),
];

/// How often to print a line, in seconds.
const double every = 0.1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (level, moves) in runs) {
    testWithGame<LevelGame>(
      'probe ${level.id}',
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        trace(game, level, moves);
      },
    );
  }
}

void trace(LevelGame game, Level level, List<Move> moves) {
  const dt = 1 / 60;
  final source = game.input.sources.first as ScriptedInput;
  var elapsed = 0.0;
  var announced = false;

  void report(String label) {
    final ghosts = [
      for (final ghost in game.shadows)
        '${ghost.isActive ? '' : 'off:'}'
            '${ghost.x.toStringAsFixed(0)},${ghost.y.toStringAsFixed(0)}'
            // A shadow standing in the light is not a thing you can climb.
            '${ghost.inLight ? '*' : ''}',
    ].join(' | ');
    final doors = [
      for (final door in game.doors) door.openFraction.toStringAsFixed(2),
    ].join(',');
    // ignore: avoid_print
    print(
      't=${elapsed.toStringAsFixed(2)} '
      'p=${game.player.x.toStringAsFixed(0)},'
      '${game.player.y.toStringAsFixed(0)} '
      'g=[$ghosts] doors=$doors r=${game.reloads} $label',
    );
  }

  // ignore: avoid_print
  print('--- ${level.id}  delays=${level.delays}  floor=${level.floorTop}');
  final step = (every / dt).round();
  for (final move in moves) {
    final frames = (move.seconds / dt).round();
    for (var frame = 0; frame < frames; frame++) {
      source.next = InputIntent(
        moveAxis: move.axis,
        jump: move.jump && frame == 0,
        jumpHeld: move.jump,
        crouch: move.crouch,
      );
      game.update(dt);
      elapsed += dt;
      if (game.completed && !announced) {
        announced = true;
        report('*** FINISHED');
      }
      if (frame % step == step - 1) report('');
    }
    report('<< $move');
  }
  if (!announced) {
    // ignore: avoid_print
    print('never finished. goal is ${_rect(level.goal)}');
  }
}

String _rect(ui.Rect r) =>
    '${r.left.toStringAsFixed(0)}..${r.right.toStringAsFixed(0)} x '
    '${r.top.toStringAsFixed(0)}..${r.bottom.toStringAsFixed(0)}';
