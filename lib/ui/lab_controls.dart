import 'package:flutter/material.dart';

import '../lab/lab_settings.dart';

/// The Phase 2 debug panel — the part of this phase that actually matters.
///
/// The plan is explicit that the code is not the deliverable; the deliverable
/// is an answer, and the answer comes from dragging these while the game runs.
/// So: no constants to recompile, no restart between values, and the delay
/// slider first because it is the one that decides whether the mechanic is a
/// chase or a maths exercise.
///
/// Wrapped in [ExcludeFocus] because a `Slider` that takes keyboard focus
/// leaves the game unable to hear the arrow keys, and the whole point is to
/// tune while playing.
class LabControls extends StatefulWidget {
  const LabControls({
    super.key,
    required this.settings,
    required this.onReload,
    this.onReread,
    this.onDump,
    this.status,
  });

  final LabSettings settings;
  final VoidCallback onReload;

  /// Read the level back off the disk. Null unless the bench was pointed at a
  /// folder — there is nothing to re-read otherwise.
  final VoidCallback? onReread;

  /// Print the level on screen as JSON, to start a new one from.
  final VoidCallback? onDump;

  /// The last thing the two above had to say, good or bad.
  ///
  /// Authoring in JSON means mistakes are typos rather than compile errors,
  /// and a typo whose only symptom is that the reload button did nothing is
  /// the worst of both. Whatever went wrong belongs where the button is.
  final String? status;

  @override
  State<LabControls> createState() => _LabControlsState();
}

class _LabControlsState extends State<LabControls> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        child: ExcludeFocus(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: const Color(0xE6202020),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedBuilder(
                animation: widget.settings,
                builder: (context, _) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      if (widget.status != null) _status(widget.status!),
                      if (_expanded) ..._body(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'shadow lab',
          style: TextStyle(
            color: Color(0xFFEDEDED),
            fontFamily: 'LiberationMono',
            fontSize: 13,
          ),
        ),
      ),
      if (widget.onDump != null)
        IconButton(
          tooltip: 'print this level as JSON',
          onPressed: widget.onDump,
          icon: const Icon(Icons.code, size: 18, color: Color(0xFFEDEDED)),
        ),
      if (widget.onReread != null)
        IconButton(
          tooltip: 'read the levels back off the disk',
          onPressed: widget.onReread,
          icon: const Icon(
            Icons.folder_open,
            size: 18,
            color: Color(0xFFEDEDED),
          ),
        ),
      IconButton(
        tooltip: 'reload scene (R)',
        onPressed: widget.onReload,
        icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFEDEDED)),
      ),
      IconButton(
        tooltip: _expanded ? 'collapse' : 'expand',
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: const Color(0xFFEDEDED),
        ),
      ),
    ],
  );

  Widget _status(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFE8B96A),
        fontFamily: 'LiberationMono',
        fontSize: 11,
        height: 1.4,
      ),
    ),
  );

  List<Widget> _body() {
    final settings = widget.settings;
    return [
      _slider(
        label: 'delay',
        value: settings.delaySeconds,
        min: LabSettings.minDelay,
        max: LabSettings.maxDelay,
        display: '${settings.delaySeconds.toStringAsFixed(1)}s',
        onChanged: (value) => settings.delaySeconds = value,
      ),
      _slider(
        label: 'opacity',
        value: settings.shadowOpacity,
        min: LabSettings.minOpacity,
        max: LabSettings.maxOpacity,
        display: settings.shadowOpacity.toStringAsFixed(2),
        onChanged: (value) => settings.shadowOpacity = value,
      ),
      _toggle(
        label: 'shadow is solid',
        value: settings.shadowIsSolid,
        onChanged: (value) => settings.shadowIsSolid = value,
      ),
      _toggle(
        label: 'shadow kills',
        value: settings.shadowKills,
        onChanged: (value) => settings.shadowKills = value,
      ),
      _toggle(
        label: 'show trail',
        value: settings.showTrail,
        onChanged: (value) => settings.showTrail = value,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Text(
          'move: A/D · jump: W/space · crouch: S · reload: R',
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontFamily: 'LiberationMono',
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ),
    ];
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [_label(label), _label(display)],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    ),
  );

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _label(label),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFFEDEDED),
      fontFamily: 'LiberationMono',
      fontSize: 12,
    ),
  );
}
