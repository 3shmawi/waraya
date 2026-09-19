import 'dart:convert';

import 'level.dart';
import 'levels.dart';

/// Where levels come from.
///
/// The campaign that ships in the app and a campaign fetched from a server are
/// the same thing to everything downstream — which is the point of the seam.
/// A remote source is then a class that fetches text and hands it to
/// [JsonLevels], not a change to how the game works.
abstract interface class LevelSource {
  /// Short name, for error messages and the debug readout.
  String get label;

  Future<List<Level>> load();
}

/// The levels written in Dart, in `levels.dart`.
///
/// Stays the authoring format for the built-in campaign: a level written as
/// code is checked by the compiler and can be referred to by name from the
/// tests that prove it is solvable. JSON is for transport, not for authoring.
class BuiltInLevels implements LevelSource {
  const BuiltInLevels([this.levels]);

  final List<Level>? levels;

  @override
  String get label => 'built in';

  @override
  Future<List<Level>> load() async => levels ?? Levels.campaign;
}

/// Levels from a string of JSON — a file, an asset, or a response body.
class JsonLevels implements LevelSource {
  const JsonLevels(this.source, {this.label = 'json', this.onSkipped});

  final String source;

  @override
  final String label;

  /// Told about each level left out because it needs a mechanic this build
  /// does not have. The player is not: they get the levels that do work, and
  /// a game that refuses to open because one level was ahead of it would be a
  /// worse game. A debug build can shout through this.
  final void Function(LevelUnsupportedException skipped)? onSkipped;

  @override
  Future<List<Level>> load() async {
    try {
      return levelsFromJson(jsonDecode(source), onSkipped: onSkipped);
    } on FormatException catch (error) {
      throw LevelFormatException('$label is not valid JSON: ${error.message}');
    }
  }
}

/// Everything from [first], then anything [second] adds that is genuinely new.
///
/// This is the shape the plan asks for: the app ships with a campaign that
/// works offline forever, and a server can only ever *add* to it. A level id
/// that already exists is ignored rather than overriding a built-in one, so a
/// bad upload cannot replace a level that is known to be solvable.
///
/// If [second] fails — no network, a server having a bad day, malformed data —
/// the player gets the built-in campaign and no error. A puzzle game that will
/// not start because a CDN is down would be a worse game than one with three
/// fewer levels.
class LevelsThenExtras implements LevelSource {
  const LevelsThenExtras(this.first, this.second, {this.onError});

  final LevelSource first;
  final LevelSource second;

  /// Called when [second] fails, so a debug build can shout about it.
  final void Function(Object error)? onError;

  @override
  String get label => '${first.label} + ${second.label}';

  @override
  Future<List<Level>> load() async {
    final base = await first.load();
    try {
      final extra = await second.load();
      final known = {for (final level in base) level.id};
      return [
        ...base,
        for (final level in extra)
          if (known.add(level.id)) level,
      ];
    } catch (error) {
      onError?.call(error);
      return base;
    }
  }
}
