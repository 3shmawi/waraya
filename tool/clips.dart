// Renders the TikTok clips frame by frame, straight out of the real game.
//
// Run: flutter test tool/clips.dart
//
// Why not just screen-record the browser: a recorded page does not run at
// sixty frames a second. Playwright's recorder took the game down to roughly
// a quarter speed, which ruins a clip twice over — the run does not get where
// the script says it should, and what comes out is choppy slow motion.
//
// So the frames are made the way golden tests are made: step the game at a
// fixed dt, paint each step into a PictureRecorder, write the PNG. Nothing is
// timed against a wall clock, so the result is exact and the same every run.
// The runs are the levels' own recorded solutions, the ones the tests replay,
// so a clip cannot
// show a solution the game no longer has.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/sfx.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/lab/lab_settings.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'package:waraya/level/playthrough.dart';

/// Where the frames land. Outside the repo: these are build output.
final String outRoot =
    Platform.environment['WARAYA_CLIP_OUT'] ??
    '${Directory.systemTemp.path}/waraya-clips';

/// Portrait, phone-shaped, because that is where these get watched.
const double clipWidth = 1080;
const double clipHeight = 1920;

/// The game is rendered short and the ground is carried down to the bottom.
///
/// Rendering the game straight into 1080x1920 does not work: the camera's
/// zoom is capped by the *width* (`WarayaConfig.zoomFor`), so a taller frame
/// buys no more of the level — only more sky, with the body left down on the
/// 86% line the game plants its ground on. In a phone-shaped clip that puts
/// the character underneath the app's own caption furniture, with two thirds
/// of the picture empty above it.
///
/// So the game gets a shorter view, which lands its ground line near the
/// middle of the clip, and the strip's own bottom rows are stretched over the
/// rest. Those rows are underground — flat and dark — so the join does not
/// read as a bar, and the app's caption and buttons end up sitting on it
/// rather than on the level.
const double stripHeight = 1400;

/// How many of the strip's bottom rows get stretched over the rest of the
/// frame. They have to start below the ground line — 86% of [stripHeight] —
/// or the join repeats it. A thin slice smears the dust in it into scratches;
/// a thick one barely stretches at all.
const int bleedRows = 150;

/// How strongly your past is drawn — the settings page's slider
/// (`GameSettings.shadowOpacity`). Unset is the game's default, 0.5; footage
/// for a phone held at arm's length, squeezed into a video, wants it
/// stronger: `WARAYA_CLIP_SHADOW=0.9`.
final double? shadowOpacity = double.tryParse(
  Platform.environment['WARAYA_CLIP_SHADOW'] ?? '',
);

const double fps = 60;
const double dt = 1 / fps;

/// A phone's own screen instead of the portrait strip, for footage shown
/// inside a drawn phone (the launch video, `tool/promo/`):
/// `WARAYA_CLIP_DEVICE=844x390@2` renders the game at a real landscape
/// phone's size — so it is framed exactly as a player sees it, readout and
/// title included — at twice the pixels.
final ({double width, double height, double scale})? device = () {
  final spec = Platform.environment['WARAYA_CLIP_DEVICE'];
  if (spec == null) return null;
  final match = RegExp(r'^(\d+)x(\d+)(?:@(\d+(?:\.\d+)?))?$').firstMatch(spec);
  if (match == null) throw ArgumentError('WARAYA_CLIP_DEVICE=$spec');
  return (
    width: double.parse(match.group(1)!),
    height: double.parse(match.group(2)!),
    scale: double.parse(match.group(3) ?? '1'),
  );
}();

/// `WARAYA_CLIP_LOOK=bench` draws the bench's grey boxes instead of the
/// game's scenery — for the devlog (`docs/media/devlog.md`), footage of a
/// thing still being built.
final LevelLook look = Platform.environment['WARAYA_CLIP_LOOK'] == 'bench'
    ? LevelLook.greyBox
    : LevelLook.silhouette;

/// `WARAYA_CLIP_IDEA=2` plays the level's second recorded wrong idea instead
/// of its solution: the devlog's «I tried this, and it did not work». A clip
/// of a wrong idea must then *not* finish the level.
final int? wrongIdea = int.tryParse(
  Platform.environment['WARAYA_CLIP_IDEA'] ?? '',
);

/// Keep one frame in this many (`WARAYA_CLIP_EVERY=2` for 30 fps). The
/// game still steps at [dt]: what is recorded is what the tests play.
final int every = int.parse(Platform.environment['WARAYA_CLIP_EVERY'] ?? '1');

/// One clip: a level, the moves to play in it, and what to do around them.
class Clip {
  const Clip({
    required this.number,
    required this.slug,
    required this.levelId,
    this.leadIn = 0.8,
    this.tail = 0.8,
    this.moves,
  });

  /// Posting order, not campaign order. See `docs/media/tiktok/README.md`.
  final int number;
  final String slug;
  final String levelId;

  /// A beat of stillness before the first move, so the first frame is not
  /// already mid-stride.
  final double leadIn;

  /// How long to keep rolling after the level is finished.
  ///
  /// Capped below [LevelGame] `_advanceDelay`: the game loads the next level
  /// nine tenths of a second after the goal is touched, and a clip that runs
  /// past that ends on a level it never showed you being solved.
  final double tail;

  /// Defaults to the level's recorded solution.
  final List<Move>? moves;

  String get name => '${number.toString().padLeft(2, '0')}-$slug';
  int get levelIndex => playable.indexWhere((l) => l.id == levelId);
  List<Move> get script =>
      moves ??
      (wrongIdea == null
          ? playable[levelIndex].solution
          : playable[levelIndex].wrongIdeas[wrongIdea! - 1]);
}

/// Every level a clip can show: the campaign, then the bench.
///
/// The bench is here for the weekly drops (`docs/media/drops.md`): a new
/// thing's video is made while it is still on trial, so it is ready the
/// Friday it is promoted — and it is the same recorded solution the tests
/// play, so the video cannot show a level the game does not accept.
final List<Level> playable = [...Levels.campaign, ...Levels.bench];

const clips = <Clip>[
  Clip(number: 1, slug: 'the-plate', levelId: 'press-it-early'),
  Clip(number: 2, slug: 'the-step', levelId: 'stand-on-yourself'),
  Clip(number: 3, slug: 'the-drop', levelId: 'take-it-with-you'),
  Clip(number: 4, slug: 'not-this-way', levelId: 'not-the-same-way-back'),
  Clip(number: 5, slug: 'go-in-low', levelId: 'go-in-low'),
  Clip(number: 6, slug: 'hold-the-door', levelId: 'hold-your-own-door'),
  // The three that came after the first six were cut. Each one is a rule the
  // earlier clips could not show, which is why they are worth their own post
  // rather than a longer version of clip one.
  Clip(number: 7, slug: 'the-key', levelId: 'close-what-you-opened'),
  Clip(number: 8, slug: 'in-the-light', levelId: 'your-shadow-is-not-here'),
  Clip(number: 9, slug: 'two-of-you', levelId: 'two-not-one'),
  // The one the rule change earned. Every clip before it now shows ducking
  // somewhere, because a body that walked past standing up is not a floor
  // any more — this is the level where that is the whole question.
  Clip(number: 10, slug: 'duck-to-build', levelId: 'not-every-step'),
  // Phase 7. Each is still one rule, but these are the first clips where the
  // rule only shows up *because* of something earlier in the same clip: the
  // step you stand on was built by a step, the lamp answer is undone a room
  // later, the gates open to a plan laid down before the first one moved.
  Clip(number: 11, slug: 'a-stair-of-you', levelId: 'stair-of-yourself'),
  Clip(number: 12, slug: 'three-gates', levelId: 'three-gates-one-past'),
  Clip(number: 13, slug: 'under-the-lamp', levelId: 'under-the-light'),
  Clip(number: 14, slug: 'dont-have-been-there', levelId: 'your-past-shuts-it'),
  Clip(number: 15, slug: 'all-of-it', levelId: 'all-of-it'),
  // The weekly drops (`docs/media/drops.md`), each one the thing it brings:
  // the first level that teaches it, then a harder one as the teaser.
  Clip(number: 16, slug: 'the-mirror', levelId: 'the-mirror-brings-you-back'),
  Clip(
    number: 17,
    slug: 'the-mirror-in-the-light',
    levelId: 'the-mirror-in-the-light',
  ),
  Clip(number: 18, slug: 'the-dog', levelId: 'the-dog'),
  Clip(number: 19, slug: 'walk-on-the-button', levelId: 'walk-on-the-button'),
  Clip(number: 20, slug: 'you-hold-the-dark', levelId: 'you-hold-the-dark'),
  Clip(number: 21, slug: 'a-chain-of-dark', levelId: 'a-chain-of-dark'),
  Clip(number: 22, slug: 'pull-it-for-me', levelId: 'pull-it-for-me'),
  Clip(
    number: 23,
    slug: 'the-basket-in-the-dark',
    levelId: 'the-basket-in-the-dark',
  ),
  // The mirror's launch, in the launch video's style
  // (docs/marketing/mirror-video.md): two of the harder ones, for its
  // montage.
  Clip(number: 24, slug: 'two-mirrors', levelId: 'two-mirrors'),
  Clip(
    number: 25,
    slug: 'all-of-it-in-the-mirror',
    levelId: 'all-of-it-in-the-mirror',
  ),
  // And the dog's (docs/marketing/dog-video.md).
  Clip(number: 26, slug: 'pace-in-the-dark', levelId: 'pace-in-the-dark'),
  Clip(number: 27, slug: 'the-dog-first', levelId: 'the-dog-first'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final family in const {
      'Cairo': 'assets/fonts/Cairo-Regular.ttf',
      'LiberationMono': 'assets/fonts/LiberationMono-Regular.ttf',
    }.entries) {
      final bytes = File(family.value).readAsBytesSync();
      await (FontLoader(family.key)..addFont(
            Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
          ))
          .load();
    }
  });

  final only = Platform.environment['WARAYA_CLIP'];
  // Any level by its id, for a clip nobody numbered: `WARAYA_CLIP_LEVEL=the-dog`.
  final level = Platform.environment['WARAYA_CLIP_LEVEL'];
  for (final clip in [
    if (level != null) Clip(number: 0, slug: level, levelId: level),
    ...clips,
  ]) {
    if (level != null && clip.number != 0) continue;
    if (only != null && only != clip.slug && only != '${clip.number}') continue;
    // Twenty-five minutes a clip: the last level's is twenty seconds long and
    // renders at about two frames a second, which ran out of ten.
    test('clip ${clip.name}', () async {
      expect(
        clip.levelIndex,
        isNonNegative,
        reason: 'no level ${clip.levelId}',
      );
      final shot = await render(clip);
      // A clip that runs the whole script and never reaches the goal is a
      // clip of somebody failing the level. Louder here than on the phone.
      expect(
        shot.finished,
        wrongIdea == null,
        reason: wrongIdea == null
            ? '${clip.levelId} was not finished in ${shot.frames} frames'
            : 'wrong idea $wrongIdea finished ${clip.levelId}',
      );
      // ignore: avoid_print
      print(
        '${clip.name}: ${shot.frames} frames '
        '(${(shot.frames * every / fps).toStringAsFixed(1)}s) -> $outRoot/${clip.name}',
      );
    }, timeout: const Timeout(Duration(minutes: 25)));
  }
}

/// Every sound the game made, and when — written next to the frames as
/// `sounds.json`, so the footage can carry the game's own sound: the
/// steps, the plate, the dog's bark (`tool/promo/sound.py` lays the files
/// down at those times). The game only ever asks an [AudioOut] to play; this
/// one writes the ask down instead.
class Tape implements AudioOut {
  double now = 0;
  final List<Map<String, Object>> played = [];

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx, {double volume = 1}) => played.add({
    't': double.parse(now.toStringAsFixed(4)),
    'file': sfx.file,
    'volume': volume,
  });
}

/// Plays [clip] and writes one PNG per frame.
Future<({int frames, bool finished})> render(Clip clip) async {
  final dir = Directory('$outRoot/${clip.name}');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  final scripted = ScriptedInput();
  final tape = Tape();
  final game = await initializeGame<LevelGame>(
    () => LevelGame(
      audio: tape,
      levels: playable,
      look: look,
      startAt: clip.levelIndex,
      inputs: [scripted],
      settings: shadowOpacity == null
          ? null
          : (LabSettings()..shadowOpacity = shadowOpacity!),
      readoutDetail: false,
      // Framed around the title in its corner; the entrance is for players.
      titleIntro: false,
    ),
  );
  final screen = device;
  game.onGameResize(
    screen == null
        ? Vector2(clipWidth, stripHeight)
        : Vector2(screen.width, screen.height),
  );
  game.update(0);

  var frame = 0;
  var ticks = 0;
  Future<void> step(InputIntent intent) async {
    scripted.next = intent;
    tape.now = ticks * dt;
    game.update(dt);
    if (ticks++ % every == 0) {
      await shoot(game, '${dir.path}/${frame.toString().padLeft(5, '0')}.png');
      frame++;
    }
  }

  // Nothing pressed, just standing there.
  for (var i = 0; i < (clip.leadIn / dt).round(); i++) {
    await step(InputIntent.none);
  }

  // Input stops the instant the level is finished, the way a player's hand
  // does. A solution that overruns its own ending would otherwise walk the
  // body on for another second and a half with nothing left to solve.
  outer:
  for (final move in clip.script) {
    final steps = (move.seconds / dt).round();
    for (var i = 0; i < steps; i++) {
      await step(
        InputIntent(
          moveAxis: move.axis,
          jump: move.jump && i == 0,
          jumpHeld: move.jump,
          crouch: move.crouch,
        ),
      );
      if (game.completed) break outer;
    }
  }

  for (var i = 0; i < (clip.tail / dt).round(); i++) {
    await step(InputIntent.none);
  }

  final finished = game.completed || game.levelIndex != clip.levelIndex;
  File('${dir.path}/sounds.json').writeAsStringSync(jsonEncode(tape.played));
  game.onRemove();
  return (frames: frame, finished: finished);
}

/// Paints one frame of [game] to [path].
Future<void> shoot(LevelGame game, String path) async {
  final screen = device;
  if (screen != null) {
    final image = await paint(
      screen.width * screen.scale,
      screen.height * screen.scale,
      (canvas) {
        canvas.scale(screen.scale);
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, screen.width, screen.height),
          ui.Paint()..color = game.backgroundColor(),
        );
        game.render(canvas);
      },
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
    return;
  }
  final strip = await paint(clipWidth, stripHeight, (canvas) {
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, clipWidth, stripHeight),
      ui.Paint()..color = game.backgroundColor(),
    );
    game.render(canvas);
  });

  final frame = await paint(clipWidth, clipHeight, (canvas) {
    final smooth = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      strip,
      const ui.Rect.fromLTWH(
        0,
        stripHeight - bleedRows,
        clipWidth,
        bleedRows * 1.0,
      ),
      const ui.Rect.fromLTRB(0, stripHeight, clipWidth, clipHeight),
      smooth,
    );
    canvas.drawImage(strip, ui.Offset.zero, smooth);
  });

  final png = await frame.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  strip.dispose();
  frame.dispose();
}

/// Rasterises [draw] at [width] x [height].
Future<ui.Image> paint(
  double width,
  double height,
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  picture.dispose();
  return image;
}
