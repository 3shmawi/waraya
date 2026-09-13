import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'sfx.dart';

/// The real [AudioOut], on top of flame_audio.
///
/// The only file in the project that imports an audio package.
class FlameAudioOut implements AudioOut {
  @override
  Future<void> preload() =>
      FlameAudio.audioCache.loadAll([for (final sfx in Sfx.values) sfx.file]);

  @override
  void play(Sfx sfx, {double volume = 1}) {
    final level = volume.clamp(0.0, 1.0);
    // Below this nobody hears it, and it still costs a player instance.
    if (level < 0.02) return;
    unawaited(_play(sfx, level));
  }

  Future<void> _play(Sfx sfx, double volume) async {
    try {
      await FlameAudio.play(sfx.file, volume: volume);
    } catch (_) {
      // A missing codec, a browser that has not had a click yet, a device with
      // no audio route: all real, none of them worth taking the game down for.
    }
  }
}
