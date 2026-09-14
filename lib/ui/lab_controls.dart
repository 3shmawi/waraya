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
  });

  final LabSettings settings;
  final VoidCallback onReload;

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
                    children: [_header(), if (_expanded) ..._body()],
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
