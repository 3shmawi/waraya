// Paints the game's mark into every app icon the project ships.
//
// Run: flutter test tool/icons.dart
//
// The icons that came with the Flutter template were the Flutter logo, on the
// home screen, in the browser tab and in the taskbar. This draws `GameMark`
// instead — the same painter the ending screen uses, which is itself the same
// picture as `site/logo.svg` — at every size each platform asks for, and
// writes the files in place.
//
// It is a test rather than a script because that is the only way to get a
// Flutter canvas without a window: `PictureRecorder` + `toImage`, exactly the
// way `tool/clips.dart` makes the clip frames and the way golden tests make
// their goldens. Nothing here is timed or random, so re-running it produces
// byte-identical files.
//
// The generated PNGs are committed. They are build output in the sense that
// this tool makes them, but they are also what every platform's build reads
// from disk, and nobody wants a Flutter build to depend on having run a test
// first.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/ui/game_mark.dart';

import 'icon_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every app icon is the game\'s mark', () async {
    for (final icon in icons) {
      final png = await render(
        icon.size,
        icon.rounded,
        icon.opaque,
        icon.maskable,
      );
      File(icon.path).writeAsBytesSync(png);
      // ignore: avoid_print
      print('${icon.path} ${icon.size}x${icon.size} ${png.length} bytes');
    }

    final frames = <int, Uint8List>{
      for (final size in windowsSizes)
        size: await render(size, true, false, false),
    };
    File(windowsIco).writeAsBytesSync(ico(frames));
    // ignore: avoid_print
    print('$windowsIco ${windowsSizes.join(', ')}');
  });
}

/// Paints the mark at [size] and encodes it as a PNG.
///
/// [opaque] drops the alpha channel rather than just filling it: Flutter's
/// own PNG encoder always writes RGBA, and an app icon that *has* an alpha
/// channel is rejected by iOS whether or not anything in it is see-through.
/// So those are re-encoded here as plain RGB. See [rgbPng].
Future<Uint8List> render(
  int size,
  bool rounded,
  bool opaque,
  bool maskable,
) async {
  final recorder = ui.PictureRecorder();
  final box = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  final canvas = Canvas(recorder, box);
  if (opaque) {
    // Only the corners are ever transparent, and only on a rounded tile —
    // but an icon with an alpha channel at all is rejected by iOS, so the
    // whole thing is laid on the mark's own darkest colour first.
    canvas.drawRect(box, Paint()..color = const Color(0xFF0E0A10));
  }
  GameMark.icon(
    rounded: rounded,
    maskable: maskable,
  ).paint(canvas, Size(box.width, box.height));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  if (opaque) {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return rgbPng(raw!.buffer.asUint8List(), size);
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Encodes [rgba] as a PNG with no alpha channel.
///
/// A PNG is a signature and then length-tagged, CRC-tagged chunks: IHDR says
/// how big it is and what a pixel looks like, IDAT is every row zlib'd with a
/// filter byte in front of it, IEND ends it. Colour type 2 is RGB, which is
/// the whole point of writing this by hand.
Uint8List rgbPng(Uint8List rgba, int size) {
  final rows = BytesBuilder();
  for (var y = 0; y < size; y++) {
    rows.addByte(0); // filter: none. These are tiny and compress fine flat.
    for (var x = 0; x < size; x++) {
      final at = (y * size + x) * 4;
      rows
        ..addByte(rgba[at])
        ..addByte(rgba[at + 1])
        ..addByte(rgba[at + 2]);
    }
  }

  final head = ByteData(13);
  head.setUint32(0, size);
  head.setUint32(4, size);
  head.setUint8(8, 8); // bits per channel
  head.setUint8(9, 2); // colour type: RGB
  // Compression, filter and interlace all have exactly one defined value.

  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ...chunk('IHDR', head.buffer.asUint8List()),
    ...chunk('IDAT', ZLibCodec(level: 9).encode(rows.toBytes())),
    ...chunk('IEND', Uint8List(0)),
  ]);
}

/// One PNG chunk: length, type, payload, CRC of the type and the payload.
Uint8List chunk(String type, List<int> payload) {
  final name = type.codeUnits;
  final length = ByteData(4)..setUint32(0, payload.length);
  final body = Uint8List.fromList([...name, ...payload]);
  final crc = ByteData(4)..setUint32(0, crc32(body));
  return Uint8List.fromList([
    ...length.buffer.asUint8List(),
    ...body,
    ...crc.buffer.asUint8List(),
  ]);
}

/// The CRC-32 the PNG spec asks for, table built on first use.
final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Packs PNGs into a Windows `.ico`.
///
/// An ICO is a six-byte header, a sixteen-byte directory entry per image, and
/// then the images. Since Vista each image may be a PNG rather than a bitmap,
/// which is what these are — so this is a container and nothing is re-encoded.
Uint8List ico(Map<int, Uint8List> frames) {
  final entries = frames.entries.toList();
  final header = ByteData(6 + entries.length * 16);
  header.setUint16(0, 0, Endian.little); // reserved
  header.setUint16(2, 1, Endian.little); // type: icon
  header.setUint16(4, entries.length, Endian.little);

  var offset = header.lengthInBytes;
  for (var i = 0; i < entries.length; i++) {
    final at = 6 + i * 16;
    final size = entries[i].key;
    final png = entries[i].value;
    // 256 is written as 0: the field is one byte wide.
    header.setUint8(at, size >= 256 ? 0 : size);
    header.setUint8(at + 1, size >= 256 ? 0 : size);
    header.setUint8(at + 2, 0); // palette colours: none, it is truecolour
    header.setUint8(at + 3, 0); // reserved
    header.setUint16(at + 4, 1, Endian.little); // colour planes
    header.setUint16(at + 6, 32, Endian.little); // bits per pixel
    header.setUint32(at + 8, png.length, Endian.little);
    header.setUint32(at + 12, offset, Endian.little);
    offset += png.length;
  }

  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final entry in entries) {
    out.add(entry.value);
  }
  return out.toBytes();
}
