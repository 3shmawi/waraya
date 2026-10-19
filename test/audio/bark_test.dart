import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The bark is a recording, cut by hand (`tools/sfx.py` says how): two
/// barks, no silence in front of them, under a second.
void main() {
  final bytes = File('assets/audio/bark.wav').readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  test('mono, 16-bit, 44.1 kHz, like every other sound in the game', () {
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint16(34, Endian.little), 16);
  });

  test('under a second: the last half second of the original is cut', () {
    final samples = (bytes.length - 44) ~/ 2;
    expect(samples / 44100, lessThan(1.0));
  });

  test('loud at once: the silence in front of the first bark is cut', () {
    var first = -1;
    for (var i = 0; i < (bytes.length - 44) ~/ 2; i++) {
      if (data.getInt16(44 + i * 2, Endian.little).abs() > 3000) {
        first = i;
        break;
      }
    }
    // The bark itself takes about 40 ms to rise; the original had 80 ms of
    // nothing before that.
    expect(first, inInclusiveRange(0, 44100 * 0.06));
  });
}
