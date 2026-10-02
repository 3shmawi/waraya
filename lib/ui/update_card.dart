import 'package:flutter/widgets.dart';

import '../level/lang.dart';
import '../licenses.dart';
import '../update/update_check.dart';
import 'words.dart';

/// A small card at the top: a newer game is out, or this one just arrived.
///
/// Not a dialog. A dialog stops the game and asks for an answer; this asks
/// for nothing — the level carries on behind it, it says what is new in a
/// line or three, and it goes when it is waved away. The same update stays
/// one tap away in the pause menu.
class UpdateCard extends StatelessWidget {
  const UpdateCard({
    super.key,
    required this.lang,
    required this.title,
    required this.notes,
    required this.onDismiss,
    this.action,
    this.onAction,
  });

  /// A newer game: its version and notes, and the button that takes it.
  factory UpdateCard.update({
    Key? key,
    required Lang lang,
    required Update update,
    required VoidCallback onTake,
    required VoidCallback onLater,
  }) {
    final w = Words(lang);
    final published = update.published;
    return UpdateCard(
      key: key,
      lang: lang,
      title: update.isNewVersion
          ? '${w.newVersion} · ${published.version}'
          : w.newVersion,
      notes: update.isNewVersion ? published.notesIn(lang) : w.smallChanges,
      action: update.route == UpdateRoute.reload ? w.refresh : w.download,
      onAction: onTake,
      onDismiss: onLater,
    );
  }

  /// This game, just updated: what came with it.
  factory UpdateCard.whatsNew({
    Key? key,
    required Lang lang,
    required Published published,
    required VoidCallback onDismiss,
  }) {
    final w = Words(lang);
    return UpdateCard(
      key: key,
      lang: lang,
      title: w.whatsNewIn(published.version),
      notes: published.notesIn(lang),
      onDismiss: onDismiss,
    );
  }

  final Lang lang;
  final String title;
  final String notes;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  static const Color _ink = Color(0xFFF3E2C6);
  static const Color _dim = Color(0xFFC9BBA9);
  static const Color _warm = Color(0xFFD9A25C);

  @override
  Widget build(BuildContext context) {
    final w = Words(lang);
    return Directionality(
      textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            // Below the corner buttons' row, so it never sits on them.
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                decoration: BoxDecoration(
                  color: const Color(0xF20E0A10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x66D9A25C)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: arabicFontFamily,
                        fontSize: 16,
                        color: _ink,
                      ),
                    ),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notes,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: arabicFontFamily,
                            fontSize: 13.5,
                            height: 1.55,
                            color: _dim,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _Pill(
                          label: action == null ? w.gotIt : w.later,
                          onTap: onDismiss,
                          quiet: action != null,
                        ),
                        if (action != null) ...[
                          const SizedBox(width: 8),
                          _Pill(label: action!, onTap: onAction ?? onDismiss),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.quiet = false});

  final String label;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: quiet ? const Color(0x00000000) : const Color(0x33D9A25C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: quiet ? const Color(0x33FFE7B0) : UpdateCard._warm,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: arabicFontFamily,
              fontSize: 14,
              color: quiet ? UpdateCard._dim : UpdateCard._ink,
            ),
          ),
        ),
      ),
    );
  }
}
