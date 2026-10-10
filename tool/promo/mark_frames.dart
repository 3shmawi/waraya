// The ending screen's walk-in, as PNG frames for the launch video's last
// card (tool/promo/film.js).
//
//   WARAYA_MARK_OUT=$WORK/mark flutter test tool/promo/mark_frames.dart
//
// Painted by the game's own GameMark — the same drawing the ending screen
// animates (lib/ui/campaign_end.dart) — so the video does not carry a second
// copy of the bodies that drifts from the game's. Two shapes:
//
//   panel/   the ending screen's panel, half again as wide as it is tall
//   tile/    a square, at the app icon's spacing: the middle of the QR code
//
// 30 frames a second over the ending's 1.5 second walk-in; the last frame is
// the settled mark, held from there.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/ui/game_mark.dart';

/// `CampaignEnd._walkIn`.
const double walkIn = 1.5;
const int fps = 30;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the ending walk-in, frame by frame', () async {
    final out = Platform.environment['WARAYA_MARK_OUT'] ??
        '${Directory.systemTemp.path}/waraya-mark';
    final frames = (walkIn * fps).round();
    for (final (name, size, mark) in [
      ('panel', const Size(600, 400), (double e) => GameMark.panel(entrance: e)),
      (
        'tile',
        const Size(400, 400),
        (double e) => GameMark(
          at: const [0.665, 0.535, 0.405],
          cornerRadius: 0.22,
          border: true,
          entrance: e,
        ),
      ),
    ]) {
      final dir = Directory('$out/$name')..createSync(recursive: true);
      for (var i = 0; i <= frames; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Offset.zero & size);
        mark(i / frames).paint(canvas, size);
        final image = await recorder.endRecording().toImage(
          size.width.round(),
          size.height.round(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${dir.path}/${i.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
    }
    // ignore: avoid_print
    print('${frames + 1} frames each -> $out');
  });
}
