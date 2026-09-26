// The Phase 7 levels, one group each.
//
// Kept out of `levels_test.dart` because these ask a different kind of
// question. A short level has one idea and one wrong idea; a long one has a
// route, and a route has many more ways of being walked than anybody would
// think to write down. So as well as the recorded runs, the groups here sweep:
// every order, every pause, driven by a small controller rather than by hand-
// written timings, and they say out loud which of those finish.
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

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  LevelGame Function() build(Level level) =>
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]);

  group('three gates, one past', () {
    final level = Levels.threeGatesOnePast;
    // The balconies, left to right, and which gate each one holds.
    final far = level.blocks[2],
        middle = level.blocks[3],
        near = level.blocks[4];

    testWithGame<LevelGame>(
      'the gates, in their own order, from a plan made before the first',
      build(level),
      (game) async {
        await game.ready();
        final run = start(game)..play(level.solution);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    test('every plate is on a balcony, and every balcony on this side', () {
      // The level is only about planning if nothing can be pressed once the
      // plan is running. A plate past the first gate would be a short level
      // stood on the end of this one.
      final first = level.doors.firstWhere((d) => d.id == 'first').closed;
      for (final plate in level.plates) {
        expect(plate.area.right, lessThan(first.left), reason: plate.opens);
        expect(
          plate.area.bottom,
          lessThan(level.floorTop - 96),
          reason: '${plate.opens} can be pressed by walking past it',
        );
      }
    });

    testWithGame<LevelGame>(
      'only one order of the three opens all three',
      build(level),
      (game) async {
        await game.ready();
        final source = game.input.sources.first as ScriptedInput;
        final names = {far: 'far', middle: 'middle', near: 'near'};
        final finished = <String>[];
        var played = 0;
        for (final route in _routes([far, middle, near])) {
          for (final pause in const [0.0, 0.6, 1.2]) {
            game.reload();
            played++;
            final seconds = _climb(game, source, route, pause);
            if (seconds != null) {
              finished.add(
                '${route.map((b) => names[b]).join(' > ')} @ $pause',
              );
            }
          }
        }

        // Every visit to all three in the gates' order finishes, at every
        // pause tried — the timing is there to be generous. Nothing else
        // does: no other order, and no route that skips a balcony.
        expect(played, 45);
        expect(finished, [
          'middle > far > near @ 0.0',
          'middle > far > near @ 0.6',
          'middle > far > near @ 1.2',
        ]);
      },
    );
  });
}

/// Every route through [stops] that visits at least one, in every order.
Iterable<List<Rect>> _routes(List<Rect> stops) sync* {
  for (final a in stops) {
    yield [a];
    for (final b in stops) {
      if (b == a) continue;
      yield [a, b];
      for (final c in stops) {
        if (c == a || c == b) continue;
        yield [a, b, c];
      }
    }
  }
}

/// Climbs onto each of [route] in turn, stands in its middle for [pause],
/// then runs right for the way out. Returns when the level was finished, or
/// null.
///
/// A controller rather than a recording because a sweep has to reach every
/// balcony from every other, and timings written by hand for forty-five
/// routes would be forty-five things to get wrong. It jumps from the floor a
/// hundred units short of the edge it is aiming at, which is inside the
/// window where a rising body clears the underside and lands on top.
double? _climb(
  LevelGame game,
  ScriptedInput source,
  List<Rect> route,
  double pause,
) {
  const dt = Playthrough.dt;
  var elapsed = 0.0;
  var stop = 0;
  var stood = 0.0;
  var rising = 0;
  var axis = 0.0;
  while (elapsed < 40) {
    final player = game.player;
    var press = false;
    if (stop >= route.length) {
      axis = 1;
    } else if (rising > 0) {
      rising--;
    } else {
      final balcony = route[stop];
      final onIt =
          player.isGrounded &&
          (player.y - balcony.top).abs() < 2 &&
          player.x > balcony.left - 20 &&
          player.x < balcony.right + 20;
      if (onIt) {
        final middle = balcony.center.dx;
        axis = (player.x - middle).abs() > 12 ? (middle - player.x).sign : 0;
        if (axis == 0) {
          stood += dt;
          if (stood >= pause) {
            stop++;
            stood = 0;
          }
        }
      } else if (player.isGrounded && player.y > balcony.bottom) {
        final takeOff = player.x > balcony.right
            ? balcony.right + 100
            : balcony.left - 100;
        if ((player.x - takeOff).abs() > 5) {
          axis = (takeOff - player.x).sign;
        } else {
          axis = (balcony.center.dx - player.x).sign;
          press = true;
          rising = 30;
        }
      } else if (player.isGrounded) {
        // On another balcony: walk off it towards this one.
        axis = (balcony.center.dx - player.x).sign;
      }
    }
    source.next = InputIntent(
      moveAxis: axis,
      jump: press,
      jumpHeld: press || rising > 0,
    );
    game.update(dt);
    elapsed += dt;
    if (game.completed) return elapsed;
  }
  return null;
}
