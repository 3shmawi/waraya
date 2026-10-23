// The last card of a weekly drop's video (docs/media/drops.md): the game's
// mark walking in, the game's name, what is new this Friday, and what is
// next — as PNG frames for tools/drop_video.sh to put after the footage.
//
//   WARAYA_DROP=mirror flutter test tool/drop_card.dart
//   WARAYA_DROP=mirror WARAYA_DROP_LANG=en WARAYA_DROP_OUT=/somewhere ...
//
// Painted by the game's own GameMark and in the game's own face, for the
// reason the clips are rendered from the game rather than recorded: one
// drawing of the bodies, not a second one that drifts. And in Dart rather
// than ffmpeg's drawtext, which does not shape Arabic — it puts the letters
// down unjoined and left to right.
//
// Nothing here is random or reads the clock: the same card every run.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/ui/game_mark.dart';

/// One Friday's drop: what it brings. Nothing about the one after it — the
/// owner's call: next Friday is a surprise, and the last thing on the card is
/// where to get the game.
class Drop {
  const Drop({required this.slug, required this.what, required this.whatEn});

  final String slug;
  final String what;
  final String whatEn;
}

/// In posting order. The plan, and why each comes where it does, is
/// docs/media/drops.md.
const drops = <Drop>[
  Drop(slug: 'mirror', what: 'المراية', whatEn: 'The mirror'),
  Drop(slug: 'dog', what: 'كلب الشارع', whatEn: 'The street dog'),
  Drop(slug: 'stairwell', what: 'بيت السلّم', whatEn: 'The stairwell'),
  Drop(slug: 'basket', what: 'السبَت', whatEn: 'The basket'),
];

/// Where the code goes: `site/get/index.html`, which sends an Android to
/// Google Play and an iPhone to the App Store — the same code as the end of
/// the launch video (docs/marketing/launch-video.md).
const getUrl = 'https://waraya.pages.dev/get';

/// [getUrl] as a QR code, at the highest error correction (H), so the mark
/// can sit over its middle. Written out rather than computed so that the
/// card needs nothing but the game to draw it; made with the `qrcode` npm
/// package, `QRCode.create(getUrl, {errorCorrectionLevel: 'H'})`, the one
/// the launch video uses. A new URL means making it again.
const qrRows = <String>[
  '#######..#.##.#.#.###.#.#.#######',
  '#.....#.####.##..###.##...#.....#',
  '#.###.#.##...####.##.##.#.#.###.#',
  '#.###.#.###..#.##..#.####.#.###.#',
  '#.###.#.##.#..#..#####.##.#.###.#',
  '#.....#.#....##.##.####.#.#.....#',
  '#######.#.#.#.#.#.#.#.#.#.#######',
  '.............##.##...............',
  '..#..####...##....#.#.##.#.#####.',
  '#.##.#...#...#.#.###.#.#####.#..#',
  '#.#.#.#.#..##...#.#.#..#.####...#',
  '.#.##..#.#........##.#..##.#.#.##',
  '#.#...#####.#.###.##.#.##.####..#',
  '###..#.####..##.#....#.#.#####..#',
  '..#.#.##.#.#######.##..#...#..#.#',
  '#.##.....##.......##..#...####...',
  '.######.####.#.##...#.##..##.....',
  '.#..#..#...#...#..###..#..#...#.#',
  '..#..###...#.##.###..###.##..##.#',
  '###.#..##..#.#.#.#.....#.#...#.##',
  '#..##.##.#......###.#..#####....#',
  '..###...#.#.....##...#..##.#....#',
  '#########......####.#...####..#.#',
  '..#....##.##.#.#..###.###....#.#.',
  '##.#######..##..#.##....#####..##',
  '........##.###..##.##...#...##.##',
  '#######.#......##.#.###.#.#.#.#.#',
  '#.....#.####..###..#..###...##.##',
  '#.###.#..####.#.##.##########....',
  '#.###.#......####..####..#.###.#.',
  '#.###.#.##..###..#.#..#.#...#####',
  '#.....#..##..##....#..#.#.#......',
  '#######..#..#..####.#...#.#.###.#',
];

const double width = 1080;
const double height = 1920;
const int fps = 30;

/// `CampaignEnd._walkIn`, then a hold long enough to get another phone out
/// and point it at the code — six seconds, as at the end of the launch video.
const double walkIn = 1.5;
const double hold = 5;

const ui.Color ink = ui.Color(0xFF0B0709);
const ui.Color cream = ui.Color(0xFFF3E2C6);
const ui.Color warm = ui.Color(0xFFD9A25C);
const ui.Color dim = ui.Color(0xFF9A8B7A);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bytes = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
    await (FontLoader('Cairo')..addFont(
          Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
        ))
        .load();
  });

  final slug = Platform.environment['WARAYA_DROP'] ?? drops.first.slug;
  final en = Platform.environment['WARAYA_DROP_LANG'] == 'en';
  final out =
      Platform.environment['WARAYA_DROP_OUT'] ??
      '${Directory.systemTemp.path}/waraya-drop';

  test('the card for $slug', () async {
    final drop = drops.firstWhere(
      (d) => d.slug == slug,
      orElse: () => throw ArgumentError('no drop called $slug'),
    );
    final dir = Directory('$out/card');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    final frames = ((walkIn + hold) * fps).round();
    for (var i = 0; i < frames; i++) {
      final t = i / fps;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        const ui.Rect.fromLTWH(0, 0, width, height),
      );
      paintCard(canvas, drop, t, en: en);
      final image = await recorder.endRecording().toImage(
        width.toInt(),
        height.toInt(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${dir.path}/${i.toString().padLeft(4, '0')}.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    }
    // ignore: avoid_print
    print('$frames frames -> ${dir.path}');
  });
}

/// One frame of the card, [t] seconds in.
void paintCard(ui.Canvas canvas, Drop drop, double t, {required bool en}) {
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, width, height),
    ui.Paint()..color = ink,
  );

  // The mark, the ending screen's panel, walking in.
  const panel = Size(600, 400);
  canvas.save();
  canvas.translate((width - panel.width) / 2, 190);
  GameMark.panel(entrance: (t / walkIn).clamp(0.0, 1.0)).paint(canvas, panel);
  canvas.restore();

  // The words come up once the bodies are in, one after another.
  double fadeIn(double from) => ((t - from) / 0.35).clamp(0.0, 1.0);
  final dir = en ? ui.TextDirection.ltr : ui.TextDirection.rtl;

  line(canvas, en ? 'Waraya' : 'ورايا', 620, 100, cream, fadeIn(0.6), dir);
  line(
    canvas,
    en ? 'New: ${drop.whatEn}' : 'جديد: ${drop.what}',
    770,
    64,
    warm,
    fadeIn(1.1),
    dir,
  );

  // And the last thing: where to get it.
  qrCard(canvas, t - 1.4, centre: const ui.Offset(width / 2, 1250), side: 460);
  line(
    canvas,
    en ? 'Scan it and get the game' : 'صوّر الكود ونزّلها',
    1545,
    54,
    cream,
    fadeIn(2.2),
    dir,
  );
  line(
    canvas,
    'Google Play · App Store',
    1640,
    38,
    dim,
    fadeIn(2.5),
    ui.TextDirection.ltr,
  );
}

/// The code on a cream card, [u] seconds after it starts: the card comes
/// up, then the code builds from one corner to the other, then the game's
/// icon lands in its middle. Rounded squares, not dots — dots did not scan
/// in the launch video.
void qrCard(
  ui.Canvas canvas,
  double u, {
  required ui.Offset centre,
  required double side,
}) {
  if (u <= 0) return;
  double prog(double from, double to) =>
      ((u - from) / (to - from)).clamp(0.0, 1.0);
  double ease(double p) => 1 - (1 - p) * (1 - p) * (1 - p);

  final n = qrRows.length;
  final pad = side * 0.07;
  final up = ease(prog(0, 0.45));
  canvas.save();
  canvas.translate(centre.dx, centre.dy + (1 - up) * 80);
  canvas.scale(0.8 + 0.2 * up);
  final card = ui.Rect.fromCenter(
    center: ui.Offset.zero,
    width: side + 2 * pad,
    height: side + 2 * pad,
  );
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(card, ui.Radius.circular(pad * 1.4)),
    ui.Paint()..color = const ui.Color(0xFFFFE7B0).withValues(alpha: up),
  );

  // One module of quiet zone inside the card's own margin.
  final cell = side / (n + 2);
  final origin = ui.Offset(-side / 2 + cell, -side / 2 + cell);
  bool finder(int r, int c) =>
      (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);
  bool hole(int r, int c) =>
      (r - (n - 1) / 2).abs() < n * 0.13 && (c - (n - 1) / 2).abs() < n * 0.13;
  final paint = ui.Paint()..color = const ui.Color(0xFF0E0A10);
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (qrRows[r][c] != '#' || finder(r, c) || hole(r, c)) continue;
      final diagonal = (r + c) / (2 * n);
      final p = ease(prog(0.3 + diagonal * 0.6, 0.5 + diagonal * 0.6));
      if (p <= 0) continue;
      final w = cell * 0.94 * p;
      final at = origin + ui.Offset((c + 0.5) * cell, (r + 0.5) * cell);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(center: at, width: w, height: w),
          ui.Radius.circular(w * 0.32),
        ),
        paint,
      );
    }
  }
  // The three corners, drawn whole: they are what a camera looks for.
  for (final (i, (r, c)) in const [(0, 0), (0, 1), (1, 0)].indexed) {
    final p = ease(prog(0.3 + i * 0.1, 0.6 + i * 0.1));
    if (p <= 0) continue;
    final at = origin + ui.Offset(c * (n - 7) * cell, r * (n - 7) * cell);
    final box = ui.Rect.fromLTWH(at.dx, at.dy, 7 * cell, 7 * cell);
    canvas.save();
    canvas.translate(box.center.dx, box.center.dy);
    canvas.scale(p);
    canvas.translate(-box.center.dx, -box.center.dy);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        box.deflate(cell / 2),
        ui.Radius.circular(cell * 1.6),
      ),
      ui.Paint()
        ..color = paint.color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = cell,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        box.deflate(2 * cell),
        ui.Radius.circular(cell * 0.9),
      ),
      paint,
    );
    canvas.restore();
  }
  // The icon over the middle, once the code is built.
  final icon = ease(prog(1.1, 1.4));
  if (icon > 0) {
    final s = cell * n * 0.24 * icon;
    canvas.save();
    canvas.translate(-s / 2, -s / 2);
    const GameMark.icon().paint(canvas, Size(s, s));
    canvas.restore();
  }
  canvas.restore();
}

void line(
  ui.Canvas canvas,
  String text,
  double y,
  double size,
  ui.Color color,
  double opacity,
  ui.TextDirection direction,
) {
  if (opacity <= 0) return;
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: ui.TextAlign.center,
            textDirection: direction,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            fontFamily: 'Cairo',
            fontSize: size,
            color: color.withValues(alpha: opacity),
          ),
        )
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width - 120));
  canvas.drawParagraph(paragraph, ui.Offset(60, y));
}
