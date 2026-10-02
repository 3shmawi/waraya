import 'package:flutter/widgets.dart';

import '../input/touch_input_source.dart';
import '../level/lang.dart';
import '../licenses.dart';
import '../settings/game_settings.dart';
import 'words.dart';

const Color _ink = Color(0xFFF3E2C6);
const Color _dim = Color(0xFF9A8B7A);
const Color _warm = Color(0xFFD9A25C);

/// The one settings screen (`docs/phase-11-feel.md` §6).
///
/// Plain widgets, no Material, like the rest of the campaign: every control is
/// a row of choices you tap, which is all a switch or a slider would be here
/// and needs no theme. Each change is applied the moment it is tapped — the
/// volume is heard on the next footstep — and written down by
/// [SettingsKeeper].
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.deviceLang,
    required this.onClose,
    this.showTouch = true,
  });

  final SettingsKeeper settings;

  /// What the device asks for, to show what «زي الجهاز» comes to.
  final Lang deviceLang;
  final VoidCallback onClose;

  /// Whether to offer the touch-button rows. A desktop has no buttons on
  /// screen, and two rows of settings for nothing are two rows of confusion.
  final bool showTouch;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSettings>(
      valueListenable: settings,
      builder: (context, now, _) {
        final lang = now.language ?? deviceLang;
        final w = Words(lang);
        void set(GameSettings next) => settings.value = next;
        return Directionality(
          textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xF20E0A10),
            child: SafeArea(
              child: Column(
                children: [
                  _Heading(title: w.settings, close: w.close, onClose: onClose),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        _Choice<bool>(
                          label: w.sound,
                          value: now.sound,
                          options: [(true, w.on), (false, w.off)],
                          onPick: (v) => set(now.copyWith(sound: v)),
                        ),
                        if (now.sound)
                          _Choice<double>(
                            label: w.volume,
                            value: now.volume,
                            options: const [
                              (0.25, '25%'),
                              (0.5, '50%'),
                              (0.75, '75%'),
                              (1.0, '100%'),
                            ],
                            onPick: (v) => set(now.copyWith(volume: v)),
                          ),
                        if (showTouch) ...[
                          _Choice<bool>(
                            label: w.haptics,
                            value: now.haptics,
                            options: [(true, w.on), (false, w.off)],
                            onPick: (v) => set(now.copyWith(haptics: v)),
                          ),
                          _Choice<ButtonSize>(
                            label: w.buttonSize,
                            value: now.buttons,
                            options: [
                              (ButtonSize.small, w.small),
                              (ButtonSize.normal, w.normal),
                              (ButtonSize.large, w.large),
                            ],
                            onPick: (v) => set(now.copyWith(buttons: v)),
                          ),
                          _Choice<double>(
                            label: w.buttonStrength,
                            value: now.buttonOpacity,
                            options: [
                              (0.4, w.faint),
                              (0.7, w.normal),
                              (1.0, w.strong),
                            ],
                            onPick: (v) => set(now.copyWith(buttonOpacity: v)),
                          ),
                        ],
                        _Choice<Lang?>(
                          label: w.language,
                          value: now.language,
                          options: [
                            (null, w.device),
                            (Lang.ar, 'عربي'),
                            (Lang.en, 'English'),
                          ],
                          onPick: (v) => set(now.copyWith(language: () => v)),
                        ),
                        _Choice<bool>(
                          label: w.stats,
                          note: w.statsWhy,
                          value: now.sendStats,
                          options: [(true, w.on), (false, w.off)],
                          onPick: (v) => set(now.copyWith(sendStats: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whether this platform draws touch buttons, for [showTouch].
  static bool get touchPlatform => TouchInputSource.isTouchPlatform;
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.close,
    required this.onClose,
  });

  final String title;
  final String close;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: arabicFontFamily,
                fontSize: 26,
                color: _ink,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: close,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x22FFE7B0),
                ),
                child: const Center(
                  child: Text('✕', style: TextStyle(fontSize: 18, color: _ink)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting: its name, and its choices as a row of pills.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onPick,
    this.note,
  });

  final String label;
  final String? note;
  final T value;
  final List<(T, String)> options;
  final void Function(T value) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: arabicFontFamily,
              fontSize: 16,
              color: _ink,
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: const TextStyle(
                  fontFamily: arabicFontFamily,
                  fontSize: 12.5,
                  height: 1.5,
                  color: _dim,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (option, text) in options)
                _Pill(
                  text: text,
                  chosen: option == value,
                  onTap: () => onPick(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.chosen, required this.onTap});

  final String text;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: chosen ? const Color(0x33D9A25C) : const Color(0x14FFE7B0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: chosen ? _warm : const Color(0x1AFFE7B0),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: arabicFontFamily,
              fontSize: 14,
              color: chosen ? _ink : _dim,
            ),
          ),
        ),
      ),
    );
  }
}
