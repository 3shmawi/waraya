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

/// One Friday's drop: what it brings, and what the one after it brings.
class Drop {
  const Drop({
    required this.slug,
    required this.what,
    required this.whatEn,
    this.next,
    this.nextEn,
  });

  final String slug;
  final String what;
  final String whatEn;

  /// Null on the last one written down: the card then says only that
  /// there is more every Friday.
  final String? next;
  final String? nextEn;
}

/// In posting order. The plan, and why each comes where it does, is
/// docs/media/drops.md.
const drops = <Drop>[
  Drop(
    slug: 'mirror',
    what: 'المراية',
    whatEn: 'The mirror',
    next: 'الكلب',
    nextEn: 'The dog',
  ),
  Drop(
    slug: 'dog',
    what: 'كلب الشارع',
    whatEn: 'The street dog',
    next: 'بيت السلّم',
    nextEn: 'The stairwell',
  ),
  Drop(
    slug: 'stairwell',
    what: 'بيت السلّم',
    whatEn: 'The stairwell',
    next: 'السبَت',
    nextEn: 'The basket',
  ),
];

const double width = 1080;
const double height = 1920;
const int fps = 30;

/// `CampaignEnd._walkIn`, then a hold long enough to read three lines.
const double walkIn = 1.5;
const double hold = 2.5;

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
  const panel = Size(720, 480);
  canvas.save();
  canvas.translate((width - panel.width) / 2, 470);
  GameMark.panel(entrance: (t / walkIn).clamp(0.0, 1.0)).paint(canvas, panel);
  canvas.restore();

  // The words come up once the bodies are in, one after another.
  double fadeIn(double from) => ((t - from) / 0.35).clamp(0.0, 1.0);
  final dir = en ? ui.TextDirection.ltr : ui.TextDirection.rtl;

  line(canvas, en ? 'Waraya' : 'ورايا', 1040, 110, cream, fadeIn(0.6), dir);
  line(
    canvas,
    en ? 'New: ${drop.whatEn}' : 'جديد: ${drop.what}',
    1210,
    64,
    warm,
    fadeIn(1.1),
    dir,
  );
  final next = en ? drop.nextEn : drop.next;
  line(
    canvas,
    next == null
        ? (en ? 'Something new every Friday' : 'كل جمعة حاجة جديدة')
        : (en ? 'Next Friday: $next' : 'الجمعة الجاية: $next'),
    1320,
    48,
    dim,
    fadeIn(1.6),
    dir,
  );
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
