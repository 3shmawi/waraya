import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/character/figure.dart';

void main() {
  group('Figure.footOffset', () {
    const h = 96.0;

    test('a planted foot travels backward, not forward', () {
      // The moonwalk bug: the first version lifted the foot on the half of the
      // cycle where it moved backward, so the grounded foot slid forward and
      // the character appeared to walk the way it was not facing.
      var checked = 0;
      for (var i = 0; i < 64; i++) {
        final a = i / 64 * 2 * pi2;
        final b = (i + 1) / 64 * 2 * pi2;
        final first = Figure.footOffset(a, h);
        final second = Figure.footOffset(b, h);
        final grounded = first.dy == 0 && second.dy == 0;
        if (!grounded) continue;
        checked++;
        expect(
          second.dx,
          lessThan(first.dx),
          reason: 'grounded foot moved forward at phase $a',
        );
      }
      expect(checked, greaterThan(10), reason: 'no grounded samples examined');
    });

    test('the lifted half of the cycle is the half that travels forward', () {
      final start = Figure.footOffset(0.05, h);
      final end = Figure.footOffset(pi2 - 0.05, h);
      expect(start.dy, lessThan(0), reason: 'should be off the ground');
      expect(end.dy, lessThan(0), reason: 'should be off the ground');
      expect(end.dx, greaterThan(start.dx), reason: 'swing carries it forward');
    });

    test('the grounded foot keeps pace with the body at mid-stance', () {
      // The other half of the moonwalk problem: the foot can travel the right
      // *direction* and still be the wrong *speed*, which is a slide. Nobody
      // spots that in a screenshot, and everybody feels it in motion.
      const midStance = 3 * pi2 / 2;
      const dPhase = 0.0001;
      final footTravel =
          Figure.footOffset(midStance + dPhase, h).dx -
          Figure.footOffset(midStance, h).dx;
      final bodyTravel = Figure.strideLengthFor(h) * dPhase / (2 * pi2);

      expect(footTravel, closeTo(-bodyTravel, 1e-6));
    });

    test('the swing foot lifts highest before mid-swing, not at it', () {
      // A run drives the knee up early and reaches forward after. A
      // symmetrical arc is a walk.
      var peak = 0.0;
      var peakPhase = 0.0;
      for (var i = 1; i < 200; i++) {
        final phase = i / 200 * pi2;
        final lift = -Figure.footOffset(phase, h).dy;
        if (lift > peak) {
          peak = lift;
          peakPhase = phase;
        }
      }
      expect(peakPhase, lessThan(pi2 / 2));
      expect(peak, greaterThan(0.1 * h), reason: 'a run picks its feet up');
    });

    test('the stride is symmetric about the hip', () {
      final back = Figure.footOffset(0, h);
      final front = Figure.footOffset(pi2, h);
      expect(back.dx, closeTo(-front.dx, 0.001));
      expect(back.dy, 0);
      expect(front.dy, closeTo(0, 0.001));
    });
  });
}

const double pi2 = 3.141592653589793;
