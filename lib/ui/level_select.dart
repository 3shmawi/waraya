import 'package:flutter/widgets.dart';

import '../level/level.dart';
import '../licenses.dart';

/// The list of levels, and the only menu in the game.
///
/// Phase 5's job is the joins between levels, and this is the first of them.
/// Deliberately not a title screen: someone handed the link lands *in* level
/// one, and only ever sees this if they ask for it or finish the campaign.
/// A menu in front of a game is friction for the person who just clicked
/// through to it.
///
/// Plain widgets, no Material. The campaign entry point skips `MaterialApp` to
/// keep the web bundle down, and a list of buttons does not need a theme.
class LevelSelect extends StatelessWidget {
  const LevelSelect({
    super.key,
    required this.levels,
    required this.unlocked,
    required this.current,
    required this.onPick,
    required this.onClose,
    this.finished = false,
  });

  final List<Level> levels;

  /// How many are playable. The rest are shown but not offered: seeing that
  /// there is more is the point of showing them at all.
  final int unlocked;

  /// Where the game is right now, marked so the list says where you are.
  final int current;

  final void Function(int index) onPick;
  final VoidCallback onClose;

  /// True when this is the screen after the last level rather than a menu the
  /// player asked for.
  final bool finished;

  static const Color _ink = Color(0xFFF3E2C6);
  static const Color _dim = Color(0xFF9A8B7A);
  static const Color _warm = Color(0xFFD9A25C);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        // Not opaque: the level carries on behind it, which keeps the menu
        // feeling like part of the game rather than a different program.
        color: const Color(0xEE0E0A10),
        child: SafeArea(
          child: Column(
            children: [
              _Header(finished: finished, onClose: onClose),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: levels.length,
                  itemBuilder: (context, i) => _Row(
                    number: i + 1,
                    level: levels[i],
                    locked: i >= unlocked,
                    playing: i == current && !finished,
                    onTap: i >= unlocked ? null : () => onPick(i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.finished, required this.onClose});

  final bool finished;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finished ? 'خلصت السبعة' : 'المراحل',
                  style: const TextStyle(
                    fontFamily: arabicFontFamily,
                    fontSize: 26,
                    color: LevelSelect._ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  finished
                      ? 'ارجع لأي واحدة، أو جرّب تحلّها بطريقة تانية.'
                      : 'اختار واحدة، أو كمّل اللي انت فيها.',
                  style: const TextStyle(
                    fontFamily: arabicFontFamily,
                    fontSize: 14,
                    color: LevelSelect._dim,
                  ),
                ),
              ],
            ),
          ),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x22FFE7B0),
        ),
        child: const Center(
          child: Text(
            '✕',
            style: TextStyle(fontSize: 18, color: LevelSelect._ink),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.number,
    required this.level,
    required this.locked,
    required this.playing,
    required this.onTap,
  });

  final int number;
  final Level level;
  final bool locked;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = locked ? LevelSelect._dim : LevelSelect._ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: playing ? const Color(0x22D9A25C) : const Color(0x14FFE7B0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: playing
                ? LevelSelect._warm
                : const Color(0x1AFFE7B0),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$number',
                style: TextStyle(
                  fontFamily: monoFontFamily,
                  fontSize: 15,
                  color: locked ? LevelSelect._dim : LevelSelect._warm,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.name,
                    style: TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 18,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // A locked level's hint would give away a puzzle nobody
                    // has reached yet, so it keeps its mouth shut.
                    locked ? 'لسه' : level.teaches,
                    style: const TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 13,
                      height: 1.5,
                      color: LevelSelect._dim,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${level.delaySeconds.toStringAsFixed(1)}s',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: monoFontFamily,
                  fontSize: 12,
                  color: locked ? LevelSelect._dim : LevelSelect._warm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
