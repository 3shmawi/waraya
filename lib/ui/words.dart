import '../level/lang.dart';

/// Every word the game's own screens say, in both languages.
///
/// The levels carry their own names and lines (`Level.nameIn`); this is the
/// rest — the buttons, the menus, the ending. One table rather than a
/// localisation package: two languages and forty lines do not need code
/// generation, and the bundle stays small.
class Words {
  const Words(this.lang);

  final Lang lang;

  bool get _en => lang == Lang.en;

  // The buttons over the game.
  String get retry => _en ? 'Start over' : 'من الأول';
  String get levels => _en ? 'Levels' : 'المراحل';
  String get pause => _en ? 'Pause' : 'وقفة';
  String get settings => _en ? 'Settings' : 'الإعدادات';
  String get resume => _en ? 'Carry on' : 'كمّل';
  String get paused => _en ? 'Paused' : 'واقفة';
  String get close => _en ? 'Close' : 'اقفل';

  // The level title.
  String get done => _en ? 'Done.' : 'خلصت.';

  // The ending.
  String get theEnd => _en ? 'Done' : 'خلصت';
  String get thesis => _en
      ? 'Every door you walked through,\nyou opened before you needed it.'
      : 'كل باب عدّيت منه،\nانت اللي فتحته من قبل ما تحتاجه.';
  String get fromLevelOne => _en ? 'From level one' : 'من أول مرحلة';
  String moreComing(int levels) => _en
      ? '${levels == 1 ? 'One level' : '$levels levels'}. And more on the way.'
      : '${_count(levels)}. وفيه كمان جاي.';

  // The level list.
  String get levelsHint => _en
      ? 'Pick one, or carry on with this one.'
      : 'اختار واحدة، أو كمّل اللي انت فيها.';
  String get locked => _en ? 'Not yet' : 'لسه';

  // The phone held upright.
  String get turnPhone =>
      _en ? 'Turn your phone on its side' : 'لف الموبايل بالعرض';
  String get turnPhoneWhy => _en
      ? 'The game needs room to see ahead.'
      : 'اللعبة محتاجة مكان تشوف فيه قدّامك.';
  String get turnForMe => _en ? 'Turn it for me' : 'لفّها انت';
  String get playUpright => _en ? 'Play upright anyway' : 'العب كده بالطول';
  String get stuckUpright => _en
      ? 'Screen will not turn? Check rotation lock — or just play.'
      : 'الشاشة مش بتلف؟ شوف قفل اللف — أو العب كده.';
  String get upright => _en ? 'Play upright' : 'اللعب بالطول';
  String get uprightWhy => _en
      ? 'For a phone that will not turn. The level shows less ahead of you.'
      : 'لو الموبايل مش بيلف. المرحلة بتبان أضيق قدّامك.';

  // The settings page.
  String get sound => _en ? 'Sound' : 'الصوت';
  String get volume => _en ? 'Volume' : 'العلو';
  String get haptics => _en ? 'Vibration' : 'الاهتزاز';
  String get buttonSize => _en ? 'Button size' : 'حجم الأزرار';
  String get buttonStrength => _en ? 'Button strength' : 'وضوح الأزرار';
  String get language => _en ? 'Language' : 'اللغة';
  String get stats => _en ? 'Send level statistics' : 'ابعت إحصائيات المراحل';
  String get statsWhy => _en
      ? 'Which levels people get stuck on. Nothing about you — see the privacy page.'
      : 'أنهي مرحلة الناس بتقف عندها. مفيش حاجة عنك — التفاصيل في صفحة الخصوصية.';
  String get on => _en ? 'On' : 'شغّال';
  String get off => _en ? 'Off' : 'مقفول';
  String get small => _en ? 'Small' : 'صغير';
  String get normal => _en ? 'Normal' : 'عادي';
  String get large => _en ? 'Large' : 'كبير';
  String get faint => _en ? 'Faint' : 'باهت';
  String get strong => _en ? 'Strong' : 'واضح';
  String get device => _en ? 'Device' : 'زي الجهاز';
}

/// How many levels, in Arabic that agrees with itself.
///
/// Not `'$n مراحل'`: three to ten take the plural, eleven and up take the
/// singular, and the campaign is a list that is meant to grow — a server can
/// append to it, so the number here is not a constant anybody will remember to
/// re-read.
String _count(int levels) => switch (levels) {
  1 => 'مرحلة واحدة',
  2 => 'مرحلتين',
  <= 10 => '${_arabicDigits(levels)} مراحل',
  _ => '${_arabicDigits(levels)} مرحلة',
};

/// Western digits read as a foreign object in the middle of an Arabic
/// sentence set in an Arabic face. The readout in the corner keeps its Latin
/// ones — that is a gauge, in a monospace, and it is not a sentence.
String _arabicDigits(int value) => '$value'.replaceAllMapped(
  RegExp(r'[0-9]'),
  (digit) => String.fromCharCode(0x0660 + int.parse(digit[0]!)),
);
