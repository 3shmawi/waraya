import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/icon_list.dart';

/// The committed app icons are the game's mark, at the sizes each platform
/// asks for.
///
/// `tool/icons.dart` paints them and this checks what it left behind. The two
/// exist as a pair because the icons are generated *and* committed: every
/// platform's build reads them straight off disk, so a build must not depend
/// on having run a tool first — which means the files can drift from the list
/// that is supposed to describe them, and only a test notices.
///
/// The pixels are not compared. Skia renders a hair differently between
/// versions and hosts, and a test that fails on a new Flutter is a test
/// people delete. What is checked is the part that actually breaks: a file
/// that is missing, the wrong size, or still the Flutter template's.
void main() {
  /// Flutter's own logo, which every one of these files used to be. It is
  /// drawn on `#0175C2` blue, and the mark is drawn on sunset.
  const templateBlue = 0x0175C2;

  for (final icon in icons) {
    test('${icon.path} is the mark at ${icon.size}', () {
      final file = File(icon.path);
      expect(file.existsSync(), isTrue, reason: '${icon.path} is missing');

      final bytes = file.readAsBytesSync();
      final header = pngHeader(bytes);
      expect(header, isNotNull, reason: '${icon.path} is not a PNG');
      expect(header!.width, icon.size);
      expect(header.height, icon.size);

      // No alpha channel at all on the ones iOS reads: colour type 2 is RGB,
      // 6 is RGBA, and iOS rejects an icon with transparency in it.
      if (icon.opaque) {
        expect(
          header.colourType,
          isNot(6),
          reason: '${icon.path} still has an alpha channel',
        );
      }

      expect(
        colours(bytes),
        isNot(contains(templateBlue)),
        reason: '${icon.path} is still the Flutter template icon',
      );
    });
  }

  test('the windows icon holds every size it says it does', () {
    final bytes = File(windowsIco).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(data.getUint16(2, Endian.little), 1, reason: 'not an .ico');

    final count = data.getUint16(4, Endian.little);
    expect(count, windowsSizes.length);

    for (var i = 0; i < count; i++) {
      final at = 6 + i * 16;
      final declared = data.getUint8(at);
      final offset = data.getUint32(at + 12, Endian.little);
      final length = data.getUint32(at + 8, Endian.little);
      final header = pngHeader(
        Uint8List.sublistView(bytes, offset, offset + length),
      );

      expect(header, isNotNull, reason: 'frame $i is not a PNG');
      // 256 is written as 0: the field is one byte wide.
      expect(header!.width, declared == 0 ? 256 : declared);
      expect(windowsSizes, contains(header.width));
    }
  });
}

/// What a PNG's IHDR says it is.
typedef PngHeader = ({int width, int height, int colourType});

/// Reads IHDR, which a PNG always opens with. No decoding: the pixels are not
/// what is being checked here.
PngHeader? pngHeader(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 26) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colourType: data.getUint8(25),
  );
}

/// Every three-byte run in the file, read as a colour.
///
/// Deliberately crude: the point is only to say "this is not the blue tile
/// the template shipped", and decoding a PNG to answer that is more machinery
/// than the question deserves. The template icons are flat colour, so the
/// blue survives compression as a literal run of bytes.
Set<int> colours(Uint8List bytes) => {
  for (var i = 0; i + 2 < bytes.length; i++)
    (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2],
};
