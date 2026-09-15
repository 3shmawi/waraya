import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'sfx.dart';

/// The real [AudioOut], on top of flame_audio.
///
/// The only file in the project that imports an audio package.
///
/// **One pool per sound, players reused.** The obvious implementation —
/// `FlameAudio.play` per sound — builds a new audio player every time, and a
/// game that plays a footstep four times a second builds them faster than the
/// platform reclaims them. Measured in a browser: fifteen seconds of running
/// created eighty-eight players, and after roughly the fiftieth the browser
/// stopped playing new ones at all. The sound goes late, then goes away.
///
/// `AudioPool` is what audioplayers provides for exactly this — "extremely
/// quick firing, repetitive or simultaneous sounds". Players are made once and
/// handed back when the sound finishes.
class FlameAudioOut implements AudioOut {
  final Map<Sfx, AudioPool> _pools = {};

  @override
  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll([
      for (final sfx in Sfx.values) sfx.file,
    ]);
    for (final sfx in Sfx.values) {
      try {
        _pools[sfx] = await FlameAudio.createPool(
          sfx.file,
          maxPlayers: sfx.voices,
        );
      } catch (_) {
        // A platform with no audio route still has to run the game.
      }
    }
  }

  @override
  void play(Sfx sfx, {double volume = 1}) {
    final level = volume.clamp(0.0, 1.0);
    // Below this nobody hears it, and it still costs a player.
    if (level < 0.02) return;
    final pool = _pools[sfx];
    // Silent until preload finishes rather than falling back to building a
    // player per call, which is the thing being fixed.
    if (pool == null) return;
    unawaited(_start(pool, level));
  }

  Future<void> _start(AudioPool pool, double volume) async {
    try {
      // The returned stop function is not needed: these pools run in
      // mediaPlayer mode, where the player hands itself back on completion.
      await pool.start(volume: volume);
    } catch (_) {
      // A missing codec, a browser that has not had a click yet, a device with
      // no audio route: all real, none worth taking the game down for.
    }
  }
}
