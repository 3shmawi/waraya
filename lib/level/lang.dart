/// Which language the words on screen are in.
///
/// Two, and only two: the game is Egyptian and speaks Egyptian Arabic, and it
/// is published on itch.io and stores outside Egypt where most players read
/// neither. See `docs/phase-11-feel.md` §4.3.
///
/// Not a mechanic. A level's English line changes what the player reads and
/// nothing they can do, so it never enters `Level.requires` — an older build
/// that drops it shows the Arabic, which is a level that plays the same.
enum Lang {
  ar,
  en;

  /// The language a device asks for, by its language code. Arabic for
  /// Arabic, English for everything else: English is the second language far
  /// more people share than any third one this project could write.
  static Lang forDevice(String languageCode) =>
      languageCode.toLowerCase() == 'ar' ? ar : en;

  bool get isRtl => this == ar;
}
