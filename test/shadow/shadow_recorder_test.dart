import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/shadow/shadow_recorder.dart';
import 'package:waraya/shadow/snapshot.dart';

PoseSnapshot poseAt(double x) => PoseSnapshot(
  x: x,
  y: 620,
  facing: 1,
  state: PoseState.walk,
  stridePhase: 0,
);

void main() {
  group('ShadowRecorder', () {
    test('stays silent until the delay has elapsed', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 1);

      for (var i = 0; i < 60; i++) {
        recorder.record(poseAt(i.toDouble()));
        expect(recorder.isPlaying, isFalse, reason: 'tick $i');
      }

      recorder.record(poseAt(60));
      expect(recorder.isPlaying, isTrue);
    });

    test('replays the path exactly, one tick per tick', () {
      // This is the whole promise of recording transforms instead of inputs:
      // the shadow is not re-simulated, so it cannot drift. If this test ever
      // needs a tolerance, the approach has been changed and the plan's
      // reasoning needs revisiting.
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 0.5);
      const delayTicks = 30;
      final path = [for (var i = 0; i < 200; i++) i * 3.7];

      for (var i = 0; i < path.length; i++) {
        recorder.record(poseAt(path[i]));
        if (i < delayTicks) {
          expect(recorder.current, isNull);
        } else {
          expect(recorder.current!.x, path[i - delayTicks]);
        }
      }
    });

    test('raising the delay pauses the shadow until the buffer refills', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 0.5);
      for (var i = 0; i <= 30; i++) {
        recorder.record(poseAt(i.toDouble()));
      }
      final before = recorder.current!.x;

      recorder.delaySeconds = 1.0;
      for (var i = 31; i < 45; i++) {
        recorder.record(poseAt(i.toDouble()));
      }

      expect(
        recorder.current!.x,
        before,
        reason:
            'shadow waits, it does not '
            'jump backwards',
      );
      expect(recorder.secondsUntilPlaying, greaterThan(0));
    });

    test('lowering the delay fast-forwards the shadow in one step', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 2);
      for (var i = 0; i <= 200; i++) {
        recorder.record(poseAt(i.toDouble()));
      }
      // 2s of delay at 60Hz is 120 ticks behind tick 200.
      expect(recorder.current!.x, 80);

      recorder.delaySeconds = 0.5;
      recorder.record(poseAt(201));
      expect(recorder.current!.x, 171, reason: '30 ticks behind 201');
    });

    test('never lets the delay fall to zero', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60);
      recorder.delaySeconds = 0;
      expect(recorder.delayTicks, greaterThanOrEqualTo(1));
    });

    test('clear wipes the history and the shadow with it', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 0.5);
      for (var i = 0; i < 100; i++) {
        recorder.record(poseAt(i.toDouble()));
      }
      expect(recorder.isPlaying, isTrue);

      recorder.clear();

      expect(recorder.isPlaying, isFalse);
      expect(recorder.current, isNull);
      expect(recorder.pending, isEmpty);
    });

    test('pending is the shadow\'s future, oldest first', () {
      final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 0.5);
      for (var i = 0; i < 40; i++) {
        recorder.record(poseAt(i.toDouble()));
      }
      expect(recorder.pending.length, 30);
      expect(recorder.pending.first.x, 10);
      expect(recorder.pending.last.x, 39);
    });
  });
}
