// The devlog's episodes, filmed in the lab itself (docs/media/devlog.md):
// the real editor, driven the way a person drives it — a cursor goes to a
// button and clicks it, a number is typed into a field, a key is held down
// to walk — and every frame painted the way the clips are, with the game's
// own sounds written down beside them.
//
//   WARAYA_EPISODE=1 WARAYA_FILM_OUT=/somewhere flutter test tool/lab_film.dart
//
// Why not a screen recording: the same reason as tool/clips.dart. A
// recorded browser runs the game at a quarter of its speed; this steps the
// widget tree at a fixed 30 frames a second, so what comes out is exact, the
// same every run, and the lab in it is the lab in the repo today.
//
// Each frame is the lab (1920x1080) laid into a phone-shaped one (1080x1920)
// under the episode's words, drawn here too — Flutter joins Arabic letters,
// ffmpeg does not. Writes <out>/<episode>/NNNNN.png and sounds.json (see
// tool/promo/sound.py); tool/promo/episode.sh makes the mp4.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_screen.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/playthrough.dart';

import 'clips.dart' show Tape;
import 'lab_episodes.dart';

const double fps = 30;
const Size lab = Size(1920, 1080);
const Size reel = Size(1080, 1920);

final String outRoot =
    Platform.environment['WARAYA_FILM_OUT'] ??
    '${Directory.systemTemp.path}/waraya-film';

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer))))
      .load();
}

void main() {
  final only = int.tryParse(Platform.environment['WARAYA_EPISODE'] ?? '');
  for (final episode in episodes) {
    if (only != null && episode.number != only) continue;
    testWidgets('episode ${episode.number}', (tester) async {
      final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent;
      final material = '${sdk.path}/artifacts/material_fonts';
      await tester.runAsync(() async {
        await _font('Cairo', 'assets/fonts/Cairo-Regular.ttf');
        await _font(
          'LiberationMono',
          'assets/fonts/LiberationMono-Regular.ttf',
        );
        await _font('MaterialIcons', '$material/MaterialIcons-Regular.otf');
        await _font('Roboto', '$material/Roboto-Regular.ttf');
      });
      final film = Film(tester, '$outRoot/${episode.slug}', episode);
      await film.open(episode.start);
      await episode.play(film);
      await film.done();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}

/// One episode: what is on the bench when it opens, and what happens.
class Episode {
  const Episode({
    required this.number,
    required this.slug,
    required this.start,
    required this.play,
  });

  final int number;
  final String slug;
  final Level start;
  final Future<void> Function(Film film) play;
}

/// The camera on the lab and the hand on its mouse and keys.
class Film {
  Film(this.tester, this.dir, this.episode) {
    final d = Directory(dir);
    if (d.existsSync()) d.deleteSync(recursive: true);
    d.createSync(recursive: true);
  }

  final WidgetTester tester;
  final String dir;
  final Episode episode;
  final Tape tape = Tape();
  final GlobalKey _boundary = GlobalKey();
  final ValueNotifier<Offset> _cursor = ValueNotifier(const Offset(960, 700));
  final ValueNotifier<double> _press = ValueNotifier(0);

  int _frame = 0;
  double get now => _frame / fps;

  // The words over the lab, and when they came up.
  String _line = '';
  String _sub = '';
  double _saidAt = -10;

  // What part of the lab the reel shows: all of it, or a closer look.
  Rect _view = Offset.zero & lab;
  Rect _viewFrom = Offset.zero & lab;
  Rect _viewTo = Offset.zero & lab;
  double _viewAt = -10;
  final double _viewFor = 0.6;

  Future<void> open(Level level) async {
    tester.view.physicalSize = lab;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(brightness: Brightness.dark),
                home: Scaffold(
                  body: EditorScreen(startFrom: level, audio: tape),
                ),
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_cursor, _press]),
                  builder: (context, _) => CustomPaint(
                    size: lab,
                    painter: _CursorPainter(_cursor.value, _press.value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tick();
  }

  /// One frame: a thirtieth of a second of the lab, painted.
  Future<void> tick() async {
    tape.now = now;
    await tester.pump(const Duration(microseconds: 33333));
    _press.value = math.max(0, _press.value - 1 / 6);
    final t = ((now - _viewAt) / _viewFor).clamp(0.0, 1.0);
    final e = t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
    _view = Rect.lerp(_viewFrom, _viewTo, e.toDouble())!;
    await tester.runAsync(() async {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Offset.zero & reel);
      _paintReel(canvas, image);
      final out = await recorder.endRecording().toImage(
        reel.width.toInt(),
        reel.height.toInt(),
      );
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$dir/${_frame.toString().padLeft(5, '0')}.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
      out.dispose();
    });
    _frame++;
  }

  Future<void> wait(double seconds) async {
    for (var i = 0; i < (seconds * fps).round(); i++) {
      await tick();
    }
  }

  /// New words over the lab.
  void say(String line, [String sub = '']) {
    _line = line;
    _sub = sub;
    _saidAt = now;
  }

  /// A closer look at [region] of the lab, or the whole of it.
  void look([Rect? region]) {
    _viewFrom = _view;
    _viewTo = region ?? Offset.zero & lab;
    _viewAt = now;
  }

  /// The cursor goes to [to], the way a hand moves one: quick, then easing in.
  Future<void> point(Offset to, {double seconds = 0.5}) async {
    final from = _cursor.value;
    final n = math.max(1, (seconds * fps).round());
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      final e = 1 - math.pow(1 - t, 3).toDouble();
      _cursor.value = Offset.lerp(from, to, e)!;
      await tick();
    }
  }

  Offset centerOf(Finder finder) => tester.getCenter(finder.first);

  /// Goes to what [finder] finds and clicks it.
  Future<void> click(Finder finder, {double seconds = 0.5}) async {
    await point(centerOf(finder), seconds: seconds);
    _press.value = 1;
    await tester.tapAt(_cursor.value);
    await wait(0.25);
  }

  /// Clicks the field labelled [label] in the panel and types [text] into
  /// it, a few letters a frame.
  Future<void> type(String label, String text) async {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    await click(field, seconds: 0.35);
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(field.first, text.substring(0, i));
      await tick();
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await wait(0.2);
  }

  /// Holds [keys] down for [seconds], the way the recorded runs walk.
  Future<void> hold(List<LogicalKeyboardKey> keys, double seconds) async {
    for (final key in keys) {
      await tester.sendKeyDownEvent(key);
    }
    await wait(seconds);
    for (final key in keys.reversed) {
      await tester.sendKeyUpEvent(key);
    }
  }

  /// Plays [moves] on the keys, the way a recorded run is played: a move's
  /// direction held for its seconds, its jump pressed at the start of it and
  /// held to the end. Each of [cues] happens once, that many seconds in.
  Future<void> run(
    List<Move> moves, {
    Map<double, void Function()> cues = const {},
    bool Function()? until,
  }) async {
    var at = 0.0;
    final due = cues.keys.toList()..sort();
    void each(double at) {
      while (due.isNotEmpty && at >= due.first - 1e-6) {
        cues[due.removeAt(0)]!();
      }
    }

    for (final move in moves) {
      final keys = [
        if (move.axis < 0) LogicalKeyboardKey.keyA,
        if (move.axis > 0) LogicalKeyboardKey.keyD,
        if (move.jump) LogicalKeyboardKey.keyW,
        if (move.crouch) LogicalKeyboardKey.keyS,
      ];
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      final frames = (move.seconds * fps).round();
      for (var i = 0; i < frames; i++) {
        each(at);
        await tick();
        at += 1 / fps;
        if (until?.call() ?? false) break;
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      if (until?.call() ?? false) return;
    }
  }

  /// Whether the lab's own status line — under its buttons — says [text]
  /// now: «solution kept», «the replay finished…».
  bool statusSays(String text) =>
      find.textContaining(text).evaluate().isNotEmpty;

  Future<void> done() async {
    await wait(0.5);
    File('$dir/sounds.json').writeAsStringSync(jsonEncode(tape.played));
    await tester.pumpWidget(const SizedBox());
  }

  // ——— the reel ———

  static const _sky = [Color(0xFFF7C032), Color(0xFFE59D00)];
  static const _ink = Color(0xFF14100A);
  static const _night = Color(0xFF0E0A10);
  static const _cream = Color(0xFFFFE7B0);

  /// The lab's frame on the reel: as wide as it goes, under the words.
  static const Rect _screen = Rect.fromLTWH(24, 760, 1032, 580.5);

  void _paintReel(Canvas canvas, ui.Image image) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, reel.width, _screen.top + _screen.height / 2),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, _screen.top),
          _sky,
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        _screen.top + _screen.height / 2,
        reel.width,
        reel.height,
      ),
      Paint()..color = _night,
    );

    // The lab, framed like a screen.
    final frame = RRect.fromRectAndRadius(
      _screen.inflate(10),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      frame.shift(const Offset(0, 18)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF1C1A20));
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(_screen, const Radius.circular(14)),
    );
    canvas.drawImageRect(
      image,
      _view,
      _screen,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // The chip, the words, the name.
    final day = episode.number.toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
    );
    _chip(canvas, 'بعمل لعبة · يوم $day', 150);
    final rise = ((now - _saidAt) / 0.35).clamp(0.0, 1.0);
    final lift = (1 - rise) * 30;
    // The line in the sky, centred in it however many lines it takes; what
    // it means under the screen, on the dark.
    final line = _paragraph(_line, 88, _ink, rise, 960, bold: true);
    canvas.drawParagraph(
      line,
      Offset(
        (reel.width - 960) / 2,
        (230 + _screen.top - line.height) / 2 + lift,
      ),
    );
    _text(canvas, _sub, _screen.bottom + 70 + lift, 52, _cream, rise);
    _text(
      canvas,
      'ورايا · لعبة ألغاز مصرية',
      1760,
      36,
      const Color(0xFF9A8B7A),
      1,
    );
  }

  void _chip(Canvas canvas, String text, double y) {
    final p = _paragraph(text, 36, _cream, 1, 900);
    final w = p.maxIntrinsicWidth + 60;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(reel.width / 2, y + p.height / 2),
          width: w,
          height: p.height + 16,
        ),
        const Radius.circular(40),
      ),
      Paint()..color = _ink,
    );
    canvas.drawParagraph(p, Offset((reel.width - 900) / 2, y));
  }

  void _text(
    Canvas canvas,
    String text,
    double y,
    double size,
    Color color,
    double opacity, {
    bool bold = false,
  }) {
    if (text.isEmpty || opacity <= 0) return;
    final p = _paragraph(text, size, color, opacity, 960, bold: bold);
    canvas.drawParagraph(p, Offset((reel.width - 960) / 2, y));
  }

  ui.Paragraph _paragraph(
    String text,
    double size,
    Color color,
    double opacity,
    double width, {
    bool bold = false,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontFamily: 'Cairo',
              fontSize: size,
              height: 1.25,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: color.withValues(alpha: opacity),
            ),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }
}

/// A mouse pointer: an arrow, and a ring that opens out when it clicks.
class _CursorPainter extends CustomPainter {
  _CursorPainter(this.at, this.press);

  final Offset at;
  final double press;

  @override
  void paint(Canvas canvas, Size size) {
    if (press > 0) {
      canvas.drawCircle(
        at,
        14 + (1 - press) * 22,
        Paint()
          ..color = const Color(0xFFFFE7B0).withValues(alpha: press * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    final arrow = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx, at.dy + 30)
      ..lineTo(at.dx + 8, at.dy + 23)
      ..lineTo(at.dx + 14, at.dy + 36)
      ..lineTo(at.dx + 19, at.dy + 34)
      ..lineTo(at.dx + 13, at.dy + 21)
      ..lineTo(at.dx + 23, at.dy + 21)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CursorPainter old) => old.at != at || old.press != press;
}
