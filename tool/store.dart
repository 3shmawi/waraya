// Renders the store images — phone screenshots and the feature graphic —
// straight out of the real game, in Arabic and in English.
//
// Run: flutter test tool/store.dart
//      WARAYA_STORE_OUT=/somewhere flutter test tool/store.dart
//
// Same method as `tool/clips.dart`, and for the same reasons: the game is
// stepped at a fixed dt through the level's own recorded solution and painted
// into a PictureRecorder, so a screenshot is exactly the game, the same every
// run, and cannot show a solution the game no longer accepts. Each shot is
// "this level, this many seconds into its solution".
//
// The screenshots are the clips' frame — 1080x1920, the game in the top 1400
// and its underground stretched below — with a caption written on that dark
// strip, which is where a phone's own furniture would sit anyway. The level
// itself is not touched: the delay and the level's name stay in the corners
// because that is what a player sees.
//
// Everything is written as RGB PNGs with no alpha channel (`rgbPng`): Google
// Play refuses a screenshot or a feature graphic that has one, whether or not
// anything in it is see-through.
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
import 'package:waraya/ui/level_hud.dart';
import 'package:waraya/ui/level_title.dart';

import 'clips.dart' show bleedRows, clipHeight, clipWidth, paint, stripHeight;
import 'icons.dart' show rgbPng;

/// Where the images land. Outside the repo: these are build output.
final String outRoot =
    Platform.environment['WARAYA_STORE_OUT'] ??
    '${Directory.systemTemp.path}/waraya-store';

const double dt = 1 / 60;

/// A screen shape a store asks for, and how much of it is the game.
class Device {
  const Device(this.name, this.width, this.height, this.strip);

  final String name;
  final double width;
  final double height;

  /// The game's own height at the top; the rest is its underground stretched
  /// down, with the caption on it. See `tool/clips.dart` for why the game is
  /// not simply rendered at the full height.
  final double strip;

  /// Text and the stretched rows scale with the width, so every size reads
  /// the same.
  double get scale => width / clipWidth;
}

const devices = <Device>[
  // Google Play: 9:16, the clips' own frame.
  Device('play', clipWidth, clipHeight, stripHeight),
  // App Store, 6.9" iPhone. Taller than 9:16, so the strip is too: the same
  // share of the width, which keeps the level framed as on Play.
  Device('iphone', 1290, 2796, 1290 * stripHeight / clipWidth),
  // App Store, 6.5" iPhone — the slot App Store Connect shows first on some
  // accounts, and it refuses the 6.9" size. 1284x2778 is one of the two it
  // takes; the other (1242x2688) is the same shape.
  Device('iphone-6.5', 1284, 2778, 1284 * stripHeight / clipWidth),
  // App Store, 13" iPad — nearly square, and the game is wide enough here
  // that it needs most of the height to show a level rather than a sliver.
  Device('ipad', 2064, 2752, 2064),
];

/// One line of store copy, in both languages.
class Words {
  const Words(this.ar, this.en);
  final String ar;
  final String en;
  String of(String lang) => lang == 'ar' ? ar : en;
}

/// One screenshot: a level, a moment in its solution, and what it says.
class Shot {
  const Shot(this.slug, this.levelId, this.at, this.title, this.line);

  final String slug;
  final String levelId;

  /// Seconds into the level's recorded solution.
  final double at;
  final Words title;
  final Words line;
}

/// In the order the store shows them. The first two are the ones most people
/// see without scrolling, so they are the idea itself: the door you opened
/// in the past, and the step that is your own body.
const shots = <Shot>[
  Shot(
    'the-door',
    'press-it-early',
    4.5,
    Words('الباب ده محدش فتحه غيرك', 'Nobody opened that door but you'),
    Words(
      'من ثانيتين ونص. ظلك بيعيد كل اللي عملته.',
      'Two and a half seconds ago. Your shadow repeats everything you did.',
    ),
  ),
  Shot(
    'stand-on-yourself',
    'stand-on-yourself',
    8.25,
    Words('أعلى من نطتك؟ اطلع على نفسك', 'Too high? Stand on yourself'),
    Words(
      'اوطى، واستنى ماضيك يبقى سلّمة.',
      'Crouch, and wait for your past to become a step.',
    ),
  ),
  Shot(
    'two-shadows',
    'stair-of-yourself',
    14.25,
    Words('ظلين بتأخيرين = سلّمة بدرجتين', 'Two shadows, two steps'),
    Words('انت مرتين، في نفس اللحظة.', 'You, twice, at the same moment.'),
  ),
  Shot(
    'the-light',
    'your-shadow-is-not-here',
    // The past body is inside the beam here, and drawn faint because of it.
    // A second later it has walked out the far side and is solid again —
    // which is the rule too, but not the half of it the caption says.
    3.75,
    Words('جوّه النور، ظلك مش موجود', 'In the light, it is not there'),
    Words(
      'مبيدوسش زرار، ولا بيشيلك، ولا بيمسكك.',
      'It presses nothing, holds nothing, catches no one.',
    ),
  ),
  Shot(
    'go-in-low',
    'go-in-low',
    5.25,
    Words('ظلك بيروح مطرح ما رحت', 'Your shadow goes where you went'),
    Words(
      'وبيعمل اللي عملته — بالظبط، وبالتأخير.',
      'And does what you did — exactly, and late.',
    ),
  ),
  Shot(
    'all-of-it',
    'all-of-it',
    3.0,
    Words(
      'ستاشر مرحلة. ومفيش زرار تسجيل.',
      'Sixteen levels. No record button.',
    ),
    Words(
      'التأخير شغال طول الوقت، سواء انت جاهز أو لأ.',
      'The delay never stops, ready or not.',
    ),
  ),
];

/// The feature graphic: Play's banner, 1024x500, shown above the listing.
const double featureWidth = 1024;
const double featureHeight = 500;

///
/// The jump off your own crouched body: the idea in one picture, on flat
/// ground, with the sky above it empty enough for the name. The staircase of
/// two shadows was the first choice and its tall block ran straight through
/// the title. `WARAYA_FEATURE=level-id@seconds` tries another.
final featureShot = () {
  final e = Platform.environment['WARAYA_FEATURE']?.split('@');
  return e == null
      ? (levelId: 'stand-on-yourself', at: 8.25)
      : (levelId: e[0], at: double.parse(e[1]));
}();
const featureTagline = Words(
  'ظلك بيعيد كل اللي عملته.',
  'Your shadow repeats everything you did.',
);

const _cream = ui.Color(0xFFFFE7B0);
const _creamSoft = ui.Color(0xB3FFE7B0);
const _ink = ui.Color(0xFF14100A);

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

  for (final lang in const ['ar', 'en']) {
    for (final device in devices) {
      for (var i = 0; i < shots.length; i++) {
        final shot = shots[i];
        test(
          '$lang ${device.name} screenshot ${i + 1} ${shot.slug}',
          () async {
            final game = await playTo(
              shot.levelId,
              shot.at,
              device.width,
              device.strip,
            );
            final strip = await paint(
              device.width,
              device.strip,
              (c) => draw(game, c),
            );
            game.onRemove();

            // The same share of the strip the clips stretch, so it always starts
            // below the ground line however tall the strip is.
            final bleed = device.strip * bleedRows / stripHeight;
            final frame = await paint(device.width, device.height, (canvas) {
              final smooth = ui.Paint()..filterQuality = ui.FilterQuality.high;
              canvas.drawImageRect(
                strip,
                ui.Rect.fromLTWH(0, device.strip - bleed, device.width, bleed),
                ui.Rect.fromLTRB(0, device.strip, device.width, device.height),
                smooth,
              );
              canvas.drawImage(strip, ui.Offset.zero, smooth);
              caption(
                canvas,
                lang,
                shot.title.of(lang),
                shot.line.of(lang),
                device: device,
              );
            });
            strip.dispose();
            await write(
              frame,
              '$lang/${device.name}/${i + 1}-${shot.slug}.png',
            );
          },
          timeout: const Timeout(Duration(minutes: 5)),
        );
      }
    }

    test('$lang feature graphic', () async {
      final game = await playTo(
        featureShot.levelId,
        featureShot.at,
        featureWidth,
        featureHeight,
      );
      // The banner is the scene and the name, not a level in progress: the
      // corner readouts are for someone playing, and at this size they are
      // smudges.
      game.camera.viewport.children
          .where((c) => c is LevelHud || c is LevelTitle)
          .toList()
          .forEach((c) => c.removeFromParent());
      game.update(0);

      final image = await paint(featureWidth, featureHeight, (canvas) {
        draw(game, canvas);
        title(canvas, lang);
      });
      game.onRemove();
      await write(image, '$lang/play/feature-graphic.png');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

/// A game in [levelId], [at] seconds into the level's recorded solution, at a
/// [width] x [height] screen.
Future<LevelGame> playTo(
  String levelId,
  double at,
  double width,
  double height,
) async {
  final index = Levels.campaign.indexWhere((l) => l.id == levelId);
  expect(index, isNonNegative, reason: 'no level $levelId');
  final scripted = ScriptedInput();
  final game = await initializeGame<LevelGame>(
    () => LevelGame(
      levels: Levels.campaign,
      look: LevelLook.silhouette,
      startAt: index,
      inputs: [scripted],
      readoutDetail: false,
      // Framed around the title in its corner; the entrance is for players.
      titleIntro: false,
    ),
  );
  game.onGameResize(Vector2(width, height));
  game.update(0);

  var t = 0.0;
  for (final move in Levels.campaign[index].solution) {
    final steps = (move.seconds / dt).round();
    for (var i = 0; i < steps; i++) {
      scripted.next = InputIntent(
        moveAxis: move.axis,
        jump: move.jump && i == 0,
        jumpHeld: move.jump,
        crouch: move.crouch,
      );
      game.update(dt);
      t += dt;
      // A shot of a level that has already moved on is a shot of the next
      // level's first frame. Louder here than in the store.
      expect(game.levelIndex, index, reason: '$levelId ended before ${at}s');
      if (t >= at) return game;
    }
  }
  fail(
    '$levelId: the solution is ${t.toStringAsFixed(2)}s, shot asks for ${at}s',
  );
}

void draw(LevelGame game, ui.Canvas canvas) {
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, game.size.x, game.size.y),
    ui.Paint()..color = game.backgroundColor(),
  );
  game.render(canvas);
}

ui.Paragraph text(
  String s,
  String lang, {
  required double size,
  required ui.Color color,
  required double width,
  ui.TextAlign align = ui.TextAlign.center,
  double height = 1.35,
  List<ui.Shadow>? shadows,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            textDirection: lang == 'ar'
                ? ui.TextDirection.rtl
                : ui.TextDirection.ltr,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            fontFamily: 'Cairo',
            fontSize: size,
            color: color,
            height: height,
            shadows: shadows,
          ),
        )
        ..addText(s);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Two lines on the screenshot's dark strip: what is happening, and why.
void caption(
  ui.Canvas canvas,
  String lang,
  String title,
  String line, {
  required Device device,
}) {
  final k = device.scale;
  final margin = 80.0 * k;
  final width = device.width - margin * 2;
  final head = text(title, lang, size: 62 * k, color: _cream, width: width);
  final sub = text(line, lang, size: 38 * k, color: _creamSoft, width: width);
  // In the middle of the strip below the ground, nearer its top: the bottom
  // of a phone-shaped screenshot is where the store's own dots sit.
  final block = head.height + 22 * k + sub.height;
  final top = device.strip + (device.height - device.strip - block) * 0.38;
  canvas.drawParagraph(head, ui.Offset(margin, top));
  canvas.drawParagraph(sub, ui.Offset(margin, top + head.height + 22 * k));
}

/// The name and the one sentence, on the sky's empty half.
void title(ui.Canvas canvas, String lang) {
  const margin = 56.0;
  const width = featureWidth * 0.46;
  // Arabic reads from the right, so the words sit on the right and the scene
  // runs into them; in English the other way round.
  final right = lang == 'ar';
  final x = right ? featureWidth - margin - width : margin;
  final align = right ? ui.TextAlign.right : ui.TextAlign.left;

  // The sky's own colour, blurred, behind dark letters: over open sky it is
  // invisible, and over a palm it is the light that keeps the word apart from
  // the tree.
  const glow = [ui.Shadow(color: ui.Color(0xE6F2B12A), blurRadius: 16)];
  final name = text(
    'ورايا',
    'ar',
    size: 86,
    color: _ink,
    width: width,
    align: align,
    height: 1.05,
    shadows: glow,
  );
  final tagline = text(
    featureTagline.of(lang),
    lang,
    size: 26,
    color: _ink,
    width: width,
    align: align,
    shadows: glow,
  );
  var y = 30.0;
  canvas.drawParagraph(name, ui.Offset(x, y));
  y += name.height - 4;
  canvas.drawParagraph(tagline, ui.Offset(x, y));
}

Future<void> write(ui.Image image, String name) async {
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final file = File('$outRoot/$name')..parent.createSync(recursive: true);
  file.writeAsBytesSync(
    rgbPng(raw!.buffer.asUint8List(), image.width, image.height),
  );
  // ignore: avoid_print
  print('${file.path} ${image.width}x${image.height}');
  image.dispose();
}
