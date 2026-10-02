import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../level/lang.dart';

/// How big the on-screen controls are drawn.
enum ButtonSize {
  small(0.8),
  normal(1.0),
  large(1.3);

  const ButtonSize(this.scale);

  /// Multiplies every radius and margin the touch controls draw with.
  final double scale;
}

/// What the player chose on the settings page (`docs/phase-11-feel.md` §6).
///
/// Nothing here touches play. Volume, buzz, button size and language are
/// paint and noise; [sendStats] decides whether a go at a level is reported.
/// The recorded solutions cannot tell any of it apart, which is what makes
/// all of it safe to offer.
///
/// Every default is the game as it was before the page existed — sound on at
/// full, Arabic or English by the device, statistics on — so a player who
/// never opens it plays exactly what they played before.
@immutable
class GameSettings {
  const GameSettings({
    this.sound = true,
    this.volume = 1,
    this.haptics = true,
    this.buttons = ButtonSize.normal,
    this.buttonOpacity = 1,
    this.language,
    this.sendStats = true,
    this.allowUpright = false,
  });

  final bool sound;

  /// 0 to 1, multiplied into every sound the game plays.
  final double volume;

  /// A short buzz on a jump, a hard landing and being put back. Phones only.
  final bool haptics;

  final ButtonSize buttons;

  /// 0.3 to 1, multiplied into how strongly the touch controls are drawn.
  final double buttonOpacity;

  /// Null follows the device. See [Lang.forDevice].
  final Lang? language;

  /// Whether each go at a level is sent (`site/privacy.html`). The store
  /// forms call these statistics optional; this is what makes that true.
  final bool sendStats;

  /// Play on a phone held upright instead of being asked to turn it.
  ///
  /// The way out of a phone that cannot turn: rotation locked, or the game
  /// installed from the browser while its manifest still said portrait — a
  /// home-screen install keeps the orientation it was installed with, and the
  /// first player to install it that way was left on the "turn your phone"
  /// screen with nothing to press.
  final bool allowUpright;

  /// What [volume] actually comes to, with [sound] folded in.
  double get loudness => sound ? volume : 0;

  /// The language to show, given the device's.
  Lang langFor(String deviceLanguageCode) =>
      language ?? Lang.forDevice(deviceLanguageCode);

  GameSettings copyWith({
    bool? sound,
    double? volume,
    bool? haptics,
    ButtonSize? buttons,
    double? buttonOpacity,
    Lang? Function()? language,
    bool? sendStats,
    bool? allowUpright,
  }) => GameSettings(
    sound: sound ?? this.sound,
    volume: volume ?? this.volume,
    haptics: haptics ?? this.haptics,
    buttons: buttons ?? this.buttons,
    buttonOpacity: buttonOpacity ?? this.buttonOpacity,
    language: language == null ? this.language : language(),
    sendStats: sendStats ?? this.sendStats,
    allowUpright: allowUpright ?? this.allowUpright,
  );

  Map<String, Object?> toJson() => {
    'sound': sound,
    'volume': volume,
    'haptics': haptics,
    'buttons': buttons.name,
    'buttonOpacity': buttonOpacity,
    'language': language?.name,
    'sendStats': sendStats,
    'allowUpright': allowUpright,
  };

  /// Reads what [toJson] wrote. Anything missing or mistyped falls back to
  /// its default, field by field: a settings file is never a reason not to
  /// start, and one bad value is no reason to lose the rest.
  factory GameSettings.fromJson(Map<String, Object?> json) {
    const d = GameSettings();
    T pick<T>(String key, T fallback) {
      final value = json[key];
      return value is T ? value : fallback;
    }

    double unit(String key, double fallback, {double min = 0}) {
      final value = json[key];
      return value is num ? value.toDouble().clamp(min, 1) : fallback;
    }

    E? named<E extends Enum>(List<E> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    return GameSettings(
      sound: pick('sound', d.sound),
      volume: unit('volume', d.volume),
      haptics: pick('haptics', d.haptics),
      buttons: named(ButtonSize.values, json['buttons']) ?? d.buttons,
      buttonOpacity: unit('buttonOpacity', d.buttonOpacity, min: 0.3),
      language: named(Lang.values, json['language']),
      sendStats: pick('sendStats', d.sendStats),
      allowUpright: pick('allowUpright', d.allowUpright),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.sound == sound &&
      other.volume == volume &&
      other.haptics == haptics &&
      other.buttons == buttons &&
      other.buttonOpacity == buttonOpacity &&
      other.language == language &&
      other.sendStats == sendStats &&
      other.allowUpright == allowUpright;

  @override
  int get hashCode => Object.hash(
    sound,
    volume,
    haptics,
    buttons,
    buttonOpacity,
    language,
    sendStats,
    allowUpright,
  );
}

/// The settings, live: everything that reads them listens here, and every
/// change is written down.
///
/// Storage failures are swallowed the way `StoredProgress` swallows them — a
/// private window keeps its settings for the session and forgets them after.
class SettingsKeeper extends ValueNotifier<GameSettings> {
  SettingsKeeper([super.value = const GameSettings(), this._prefs]);

  final SharedPreferences? _prefs;

  static const String _prefix = 'waraya.settings.';

  /// Reads what was stored. Never throws.
  static Future<SettingsKeeper> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = <String, Object?>{
        for (final key in prefs.getKeys())
          if (key.startsWith(_prefix))
            key.substring(_prefix.length): prefs.get(key),
      };
      return SettingsKeeper(GameSettings.fromJson(json), prefs);
    } catch (_) {
      return SettingsKeeper();
    }
  }

  @override
  set value(GameSettings next) {
    if (next == value) return;
    super.value = next;
    _save(next);
  }

  Future<void> _save(GameSettings settings) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      for (final MapEntry(:key, :value) in settings.toJson().entries) {
        final full = '$_prefix$key';
        switch (value) {
          case null:
            await prefs.remove(full);
          case final bool b:
            await prefs.setBool(full, b);
          case final double n:
            await prefs.setDouble(full, n);
          case final String s:
            await prefs.setString(full, s);
        }
      }
    } catch (_) {
      // Kept in memory for this session either way.
    }
  }
}
