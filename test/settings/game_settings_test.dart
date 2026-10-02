import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/sfx.dart';
import 'package:waraya/lab/lab_settings.dart';
import 'package:waraya/level/attempts.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/settings/game_settings.dart';

class _Heard implements AudioOut {
  final List<double> volumes = [];

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx, {double volume = 1}) => volumes.add(volume);
}

class _Rows implements AttemptSink {
  int count = 0;

  @override
  void record(Attempt attempt) => count++;
}

/// The settings page's choices (`docs/phase-11-feel.md` §6).
void main() {
  test('untouched settings are the game as it was', () {
    const settings = GameSettings();
    expect(settings.loudness, 1);
    expect(settings.haptics, isTrue);
    expect(settings.buttons.scale, 1);
    expect(settings.buttonOpacity, 1);
    expect(settings.sendStats, isTrue);
    expect(settings.language, isNull);
    expect(settings.allowUpright, isFalse);
    expect(
      settings.shadowOpacity,
      LabSettings().shadowOpacity,
      reason: 'the shadow as it has always been drawn',
    );
  });

  test('the language follows the device until it is chosen', () {
    const settings = GameSettings();
    expect(settings.langFor('ar'), Lang.ar);
    expect(settings.langFor('en'), Lang.en);
    // Anything that is not Arabic reads English: it is the second language
    // far more people share than any third one.
    expect(settings.langFor('fr'), Lang.en);
    expect(settings.copyWith(language: () => Lang.ar).langFor('en'), Lang.ar);
    expect(
      settings
          .copyWith(language: () => Lang.ar)
          .copyWith(language: () => null)
          .langFor('en'),
      Lang.en,
      reason: 'back to following the device',
    );
  });

  test('written and read back, every choice survives', () {
    final chosen = const GameSettings().copyWith(
      sound: false,
      volume: 0.5,
      haptics: false,
      buttons: ButtonSize.large,
      buttonOpacity: 0.4,
      language: () => Lang.en,
      sendStats: false,
      allowUpright: true,
      shadowOpacity: 0.9,
    );
    expect(GameSettings.fromJson(chosen.toJson()), chosen);
  });

  test('a bad value costs that value, not the rest', () {
    final read = GameSettings.fromJson({
      'sound': 'yes',
      'volume': 7,
      'buttons': 'enormous',
      'buttonOpacity': 0,
      'language': 'fr',
      'sendStats': false,
    });
    expect(read.sound, isTrue);
    expect(read.volume, 1, reason: 'clamped');
    expect(read.buttons, ButtonSize.normal);
    expect(read.buttonOpacity, 0.3, reason: 'never invisible');
    expect(read.language, isNull);
    expect(read.sendStats, isFalse, reason: 'the good one is kept');
  });

  test('the volume reaches every sound, and off is silence', () {
    final heard = _Heard();
    var settings = const GameSettings(volume: 0.5);
    final audio = ScaledAudio(heard, loudness: () => settings.loudness);
    audio.play(Sfx.jump, volume: 0.4);
    expect(heard.volumes.single, closeTo(0.2, 1e-9));

    settings = settings.copyWith(sound: false);
    audio.play(Sfx.jump);
    expect(heard.volumes, hasLength(1));
  });

  test('statistics off sends nothing, from the very next row', () {
    final rows = _Rows();
    var allowed = true;
    final sink = ConsentedSink(rows, allowed: () => allowed);
    const attempt = Attempt(
      attemptId: 'a',
      levelId: 'l',
      delays: [1],
      outcome: 'finished',
      seconds: 1,
      reloads: 0,
      deaths: [],
    );
    sink.record(attempt);
    allowed = false;
    sink.record(attempt);
    sink.record(attempt);
    expect(rows.count, 1);
  });

  test('a keeper with nowhere to write still keeps the choice', () {
    final keeper = SettingsKeeper();
    var heard = 0;
    keeper.addListener(() => heard++);
    keeper.value = keeper.value.copyWith(haptics: false);
    keeper.value = keeper.value.copyWith(haptics: false);
    expect(keeper.value.haptics, isFalse);
    expect(heard, 1, reason: 'the same value twice is one change');
  });
}
