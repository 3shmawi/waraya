import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/props.dart';
import 'package:waraya/shadow/shadow_recorder.dart';
import 'package:waraya/shadow/snapshot.dart';

void main() {
  test('the trail draws every buffered position, not every sixth', () {
    // Subsampling made the line shimmer and its ends jump: the buffer shifts
    // by one entry per tick, so "every sixth entry" is a different six every
    // tick. Pinning one point per snapshot is what stops the dancing.
    final recorder = ShadowRecorder(tickRate: 1 / 60, delaySeconds: 2);
    for (var i = 0; i < 100; i++) {
      recorder.record(
        PoseSnapshot(
          x: i * 2.0,
          y: 620,
          facing: 1,
          state: PoseState.walk,
          stridePhase: 0,
        ),
      );
    }

    final trail = ShadowTrail(recorder: recorder, enabled: () => true);
    final points = trail.points().toList();

    expect(points, hasLength(recorder.pending.length));
    expect(points.first.dx, 0, reason: 'oldest first: the shadow is here next');
    expect(points.last.dx, 198, reason: 'newest last: the player is here now');
  });
}
