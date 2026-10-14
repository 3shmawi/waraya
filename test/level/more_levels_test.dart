// The Phase 12 levels (`docs/phase-12-more.md` §1.1), one group each.
//
// Same reasoning as `hard_levels_test.dart`: a recorded solution and a few
// recorded wrong ideas say the level can be finished and that the obvious
// mistakes fail, but each of these is held up by one or two numbers — how far
// out a step still reaches, how long the crawl back is — and a route has more
// ways of being walked than anybody writes down. So the groups here sweep the
// numbers: every duck length, every step position near an edge, every pause a
// thinking player might take, and they say which of those finish.
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame Function() build(Level level) =>
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]);

  group('in under, back over', () {
    final level = Levels.inUnderBackOver;

    // The whole level rests on this: going back through the tunnel is shut
    // however long you held the plate, because your past is on the reversed
    // button before you can be at the gate.
    for (final duck in const [0.5, 1.5, 3.0, 5.0]) {
      testWithGame<LevelGame>(
        'the tunnel back is shut after ducking ${duck}s on the plate',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..walkTo(-480)
            ..walkTo(-822, crouch: true)
            ..walkTo(-845)
            ..hold(duck, crouch: true)
            ..walkTo(-480, crouch: true)
            ..hold(8, axis: 1);

          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    for (final pause in const [0.0, 1.0, 2.0]) {
      testWithGame<LevelGame>(
        'over the roof survives stopping ${pause}s to look',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..walkTo(-480)
            ..walkTo(-822, crouch: true)
            ..walkTo(-845);
          final ducked = run.t;
          run
            ..hold(1.5, crouch: true)
            ..walkTo(-990)
            ..waitUntil(ducked + 3.2)
            ..climb(1)
            ..hold(pause)
            ..hold(8, axis: 1);

          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    // The lamp is what makes it one route. A step ducked anywhere clear of
    // it, on the spawn side, is too far out to put you on the roof.
    for (final x in const <double>[-345, -330, -310, -280]) {
      testWithGame<LevelGame>(
        'a step on the near side at $x does not reach the roof',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)..walkTo(x);
          final ducked = run.t;
          run
            ..hold(1.5, crouch: true)
            ..walkTo(x + 130)
            ..waitUntil(ducked + 3.2)
            ..climb(-1);

          expect(run.highest, greaterThan(_roof.top), reason: run.where);
        },
      );
    }
  });

  group('stand so it stays', () {
    final level = Levels.standToStay;

    testWithGame<LevelGame>(
      'stood on under the lamp, the key is yours alone and stays thrown',
      build(level),
      (game) async {
        await game.ready();
        final run = _Run(game)
          ..play(level.solution.take(6))
          // Long past the moment your past arrives on it.
          ..hold(level.delaySeconds + 3);

        expect(game.doors.last.openFraction, 1, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'ducked on under the lamp, your past arrives and throws it back',
      build(level),
      (game) async {
        await game.ready();
        final run = _Run(game)
          ..play(level.solution.take(5))
          ..hold(0.3, crouch: true)
          ..hold(level.delaySeconds + 1);

        expect(game.doors.last.openFraction, 0, reason: run.where);
      },
    );
  });

  group('the step that shuts', () {
    final level = Levels.theStepThatShuts;
    // How the step is climbed: from about a body and a half back.
    const runUp = 110.0;

    // Step first, then the plate, then climb — the level's answer — with
    // the step anywhere on the reversed button near enough to jump from.
    for (final x in const <double>[250, 300, 336, 370]) {
      testWithGame<LevelGame>(
        'a step at $x on the button, then the plate, then up',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)..walkTo(x);
          final ducked = run.t;
          run
            ..hold(1.5, crouch: true)
            ..pressBalconyPlate()
            ..walkTo(x - runUp)
            ..waitUntil(ducked + level.delaySeconds + 0.1)
            ..climb(1)
            ..hold(6, axis: 1);

          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    // The way out of the order would be a step that does not press the
    // button: a body less than a footprint over its edge. Every such place
    // is too far from the shelf to climb from.
    for (final x in const <double>[150, 170, 180, 186, 192]) {
      testWithGame<LevelGame>(
        'a step off the button at $x does not reach the shelf',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..pressBalconyPlate()
            ..walkTo(x);
          final ducked = run.t;
          run
            ..hold(1.5, crouch: true)
            ..walkTo(x - runUp)
            ..waitUntil(ducked + level.delaySeconds + 0.1)
            ..climb(1);

          expect(run.highest, greaterThan(430), reason: run.where);
        },
      );
    }

    for (final pause in const [1.0, 2.0]) {
      testWithGame<LevelGame>(
        'stopping ${pause}s on the shelf before the gate is not fatal',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..play(level.solution.take(12))
            ..hold(pause)
            ..play(level.solution.skip(12));

          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    // And the order every level before taught fails however long the
    // plate was held: whatever your past held, it then ducks on the button.
    for (final stand in const [0.5, 1.5, 3.0]) {
      testWithGame<LevelGame>(
        'the plate (${stand}s) and then the step leaves the gate shut',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)..pressBalconyPlate(stand: stand);
          run.walkTo(336);
          final ducked = run.t;
          run
            ..hold(1.0, crouch: true)
            ..walkTo(336 - runUp)
            ..waitUntil(ducked + level.delaySeconds + 0.1)
            ..climb(1)
            ..hold(8, axis: 1);

          expect(run.finishedAt, isNull, reason: run.where);
          expect(game.player.y, 430, reason: 'it should fail at the gate');
        },
      );
    }
  });

  group('a stair in the dark', () {
    final level = Levels.stairInTheDark;

    // The second lamp's edge is at 860, so a body touches it from a centre
    // of 838; the top step can be jumped from up to about 120 out from the
    // roof at 900. Between the two is the stair.
    for (final (x, works) in const [
      (770.0, false), // too far out to jump from the top
      (790.0, true),
      (813.0, true),
      (835.0, true),
      (845.0, false), // the top step touches the lamp
      (870.0, false), // under it, where the first room said a step goes
    ]) {
      testWithGame<LevelGame>(
        'a stair at $x ${works ? 'reaches' : 'does not reach'} the roof',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..play(level.solution.take(6))
            ..walkTo(x)
            ..play(level.solution.skip(7));

          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    testWithGame<LevelGame>(
      'under the lamp, the bottom step is there and the top one is not',
      build(level),
      (game) async {
        await game.ready();
        final run = _Run(game)
          ..play(level.solution.take(6))
          ..walkTo(880);
        var bottomLit = false;
        var topLit = false;
        // Build the stair, and watch both pasts while it stands.
        for (final move in level.solution.skip(7).take(6)) {
          run.hold(
            move.seconds,
            axis: move.axis,
            jump: move.jump,
            crouch: move.crouch,
            each: () {
              for (final ghost in game.shadows) {
                if (!ghost.isActive || ghost.crouch < 0.75) continue;
                final floating = ghost.y < 430;
                if (floating && ghost.inLight) topLit = true;
                if (!floating && ghost.inLight) bottomLit = true;
              }
            },
          );
        }

        expect(bottomLit, isFalse, reason: 'the lamp misses a ducked body');
        expect(topLit, isTrue, reason: 'and touches the one above it');
      },
    );
  });

  group('all of it, again', () {
    final level = Levels.allOfItAgain;

    for (final duck in const [0.8, 1.5, 3.0]) {
      testWithGame<LevelGame>(
        'the tunnel is shut after ducking ${duck}s on the plate',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..play(level.solution.take(15))
            ..walkTo(1848)
            ..hold(duck, crouch: true)
            ..walkTo(2190, crouch: true)
            ..hold(8, axis: 1);

          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    for (final pause in const [1.0, 2.0]) {
      testWithGame<LevelGame>(
        'stopping ${pause}s on the shelf and on the roof is not fatal',
        build(level),
        (game) async {
          await game.ready();
          final run = _Run(game)
            ..play(level.solution.take(12))
            ..hold(pause)
            ..play(level.solution.skip(12).take(9))
            ..hold(pause)
            ..play(level.solution.skip(21));

          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }
  });
}

/// The roof of the tunnel in `inUnderBackOver`.
const _roof = Rect.fromLTRB(-800, 430, -500, 540);

/// A small controller for runs that are easier to say as places than as
/// times: walk to here, duck there, climb what is in front of you.
class _Run {
  _Run(this.game) : _source = game.input.sources.first as ScriptedInput;

  final LevelGame game;
  final ScriptedInput _source;

  double t = 0;
  double? finishedAt;

  /// The highest the feet have been while standing on something.
  double highest = double.infinity;

  void _frame(InputIntent intent) {
    _source.next = intent;
    game.update(Playthrough.dt);
    t += Playthrough.dt;
    if (game.completed) finishedAt ??= t;
    if (game.player.isGrounded && game.player.y < highest) {
      highest = game.player.y;
    }
  }

  void hold(
    double seconds, {
    double axis = 0,
    bool jump = false,
    bool crouch = false,
    void Function()? each,
  }) {
    final frames = (seconds / Playthrough.dt).round();
    for (var i = 0; i < frames; i++) {
      _frame(
        InputIntent(
          moveAxis: axis,
          jump: jump && i == 0,
          jumpHeld: jump,
          crouch: crouch,
        ),
      );
      each?.call();
    }
  }

  void play(Iterable<Move> moves) {
    for (final move in moves) {
      hold(move.seconds, axis: move.axis, jump: move.jump, crouch: move.crouch);
    }
  }

  /// Walks to [x] and stops there, braking in time not to overshoot.
  void walkTo(double x, {bool crouch = false}) {
    var last = game.player.x;
    for (var guard = 0; guard < 1200; guard++) {
      final gap = x - game.player.x;
      if (gap.abs() <= 4) break;
      final speed = (game.player.x - last).abs() / Playthrough.dt;
      last = game.player.x;
      // Stopping distance under the game's ground friction.
      final brake = speed * speed / 6000 >= gap.abs() - 2;
      _frame(InputIntent(moveAxis: brake ? 0 : gap.sign, crouch: crouch));
    }
    hold(0.15, crouch: crouch);
  }

  void waitUntil(double time) {
    while (t < time) {
      _frame(InputIntent.none);
    }
  }

  /// Onto the step ahead, and off it onto whatever is beyond it.
  void climb(double direction) {
    hold(0.55, axis: direction, jump: true);
    hold(0.1);
    hold(0.7, axis: direction, jump: true);
  }

  /// Up onto the balcony in `theStepThatShuts` and stand on its plate.
  void pressBalconyPlate({double stand = 0.6}) {
    if (game.player.x < 0) {
      walkTo(-40);
      hold(0.55, axis: 1, jump: true);
    } else {
      walkTo(170);
      hold(0.55, axis: -1, jump: true);
    }
    walkTo(50);
    hold(stand);
  }

  String get where =>
      't=${t.toStringAsFixed(2)} '
      'x=${game.player.x.toStringAsFixed(0)} '
      'y=${game.player.y.toStringAsFixed(0)} '
      'reloads=${game.reloads}';
}
