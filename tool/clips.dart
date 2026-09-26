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
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'package:waraya/level/playthrough.dart';

/// Where the frames land. Outside the repo: these are build output.
final String outRoot =
    Platform.environment['WARAYA_CLIP_OUT'] ?? '${Directory.systemTemp.path}/waraya-clips';

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

const double fps = 60;
const double dt = 1 / fps;

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
  int get levelIndex => Levels.campaign.indexWhere((l) => l.id == levelId);
  List<Move> get script => moves ?? Levels.campaign[levelIndex].solution;
}

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
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final family in const {
      'Cairo': 'assets/fonts/Cairo-Regular.ttf',
      'LiberationMono': 'assets/fonts/LiberationMono-Regular.ttf',
    }.entries) {
      final bytes = File(family.value).readAsBytesSync();
      await (FontLoader(family.key)
            ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer))))
          .load();
    }
  });

  final only = Platform.environment['WARAYA_CLIP'];
  for (final clip in clips) {
    if (only != null && only != clip.slug && only != '${clip.number}') continue;
    test('clip ${clip.name}', () async {
      final shot = await render(clip);
      // A clip that runs the whole script and never reaches the goal is a
      // clip of somebody failing the level. Louder here than on the phone.
      expect(
        shot.finished,
        isTrue,
        reason: '${clip.levelId} was not finished in ${shot.frames} frames',
      );
      // ignore: avoid_print
      print(
        '${clip.name}: ${shot.frames} frames '
        '(${(shot.frames / fps).toStringAsFixed(1)}s) -> $outRoot/${clip.name}',
      );
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}

/// Plays [clip] and writes one PNG per frame.
Future<({int frames, bool finished})> render(Clip clip) async {
  final dir = Directory('$outRoot/${clip.name}');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  final scripted = ScriptedInput();
  final game = await initializeGame<LevelGame>(
    () => LevelGame(
      levels: Levels.campaign,
      look: LevelLook.silhouette,
      startAt: clip.levelIndex,
      inputs: [scripted],
      readoutDetail: false,
    ),
  );
  game.onGameResize(Vector2(clipWidth, stripHeight));
  game.update(0);

  var frame = 0;
  Future<void> step(InputIntent intent) async {
    scripted.next = intent;
    game.update(dt);
    await shoot(game, '${dir.path}/${frame.toString().padLeft(5, '0')}.png');
    frame++;
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
  game.onRemove();
  return (frames: frame, finished: finished);
}

/// Paints one frame of [game] to [path].
Future<void> shoot(LevelGame game, String path) async {
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
