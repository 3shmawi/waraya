import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../level/level.dart';
import '../level/level_check.dart';
import '../level/level_upload.dart';
import '../level/levels.dart';
import '../level/playthrough.dart';
import '../ui/lab_controls.dart';
import '../ui/upload_dialog.dart';
import 'editor.dart';
import 'editor_doc.dart';
import 'editor_game.dart';
import 'editor_overlay.dart';
import 'level_file.dart';

/// The bench, with an editor in it (`docs/phase-9-editor.md`).
///
/// One screen, two modes, one game. Editing, the level stands still with its
/// pieces outlined and the rules drawn over it; Tab, and you are in it —
/// the same [EditorGame], the same rectangles, the same physics — and Tab
/// again puts you back where you were looking. The editor is a way of
/// changing the level the bench plays, not a second thing that draws one.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.startFrom,
    this.extraLevels = const [],
    this.upload,
    this.onReread,
    this.saveFolder,
    this.audio,
  });

  /// What is on the bench when it opens.
  final Level startFrom;

  /// Levels read off the disk, offered as places to start alongside the
  /// campaign.
  final List<Level> extraLevels;

  /// Where the cloud button sends a level. Null hides it.
  final LevelUpload? upload;

  /// Reads the bench's folder again. Null when it was not pointed at one.
  final Future<List<Level>> Function()? onReread;

  /// Where a saved level is written on a desktop — the folder the bench
  /// reads, so the folder button picks it straight back up.
  final String? saveFolder;

  /// Silent when null — the tests.
  final AudioOut? audio;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _editor = EditorController(
    EditorDoc.fromLevel(widget.startFrom),
  );
  late final EditorGame _game = EditorGame(
    level: widget.startFrom,
    audio: widget.audio ?? const SilentAudio(),
  );
  final FocusNode _gameFocus = FocusNode(debugLabel: 'game');

  late List<Level> _extra = widget.extraLevels;
  int _builtRevision = 0;
  String? _status;

  /// The cheap half of the gate, redone on every change.
  List<Finding> _numbers = const [];

  /// The whole gate, run once the level has stood still for a moment.
  Verdict? _verdict;
  int _verdictFor = -1;
  bool _checking = false;
  Timer? _checkSoon;

  /// Set while the pointer is panning the camera instead of dragging a piece.
  Offset? _panFrom;

  @override
  void initState() {
    super.initState();
    _game.onRunEnded = _runEnded;
    _editor.addListener(_changed);
    _game.camera.viewfinder.add(EditorOverlay(game: _game, editor: _editor));
    _recheck();
  }

  @override
  void dispose() {
    _checkSoon?.cancel();
    _clock?.cancel();
    _editor.removeListener(_changed);
    _gameFocus.dispose();
    super.dispose();
  }

  Level get _level => _editor.level;
  EditorMode get _mode => _game.mode;
  bool get _editing => _mode == EditorMode.editing;

  void _changed() {
    if (_editor.revision != _builtRevision) {
      _builtRevision = _editor.revision;
      if (_editing) _game.edit(_level);
      _recheck();
    }
    setState(() {});
  }

  // ——— the gate, while you work ———

  void _recheck() {
    _numbers = checkNumbers(_level);
    _checkSoon?.cancel();
    _checkSoon = Timer(const Duration(milliseconds: 700), _runGate);
  }

  /// The replays: the solution, every wrong idea, every cheap run. Only while
  /// editing and not mid-drag — they take a moment, and a moment every frame
  /// of a drag is a drag that does not move.
  Future<void> _runGate() async {
    if (!_editing || _editor.dragging) {
      _checkSoon = Timer(const Duration(milliseconds: 700), _runGate);
      return;
    }
    final revision = _editor.revision;
    if (_verdictFor == revision) return;
    setState(() => _checking = true);
    // Give the "checking" a frame to show before the replays take the thread.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final verdict = await checkLevel(_level);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (_editor.revision == revision) {
        _verdict = verdict;
        _verdictFor = revision;
      }
    });
  }

  // ——— modes ———

  Future<void> _toEdit() async {
    _game.stop();
    await _game.edit(_level);
    setState(() {});
  }

  Future<void> _play() async {
    await _game.play(_level);
    _gameFocus.requestFocus();
    setState(() => _status = 'playing — Tab to go back to editing');
  }

  /// Ticks the run's clock on screen while a take is going.
  Timer? _clock;

  void _watchRun() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || _editing) {
        timer.cancel();
        _clock = null;
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _record(RunKind kind) async {
    await _game.record(_level, kind);
    _watchRun();
    _gameFocus.requestFocus();
    setState(
      () => _status = kind == RunKind.solution
          ? 'recording the solution — it stops at the goal · R starts over'
          : 'recording a wrong idea — Esc or stop when it has failed · R starts '
                'over',
    );
  }

  Future<void> _replay(List<Move> moves, String what) async {
    await _game.replay(_level, moves);
    _watchRun();
    _gameFocus.requestFocus();
    setState(() => _status = 'replaying $what');
  }

  void _runEnded(RunEnded run) {
    final seconds = run.at?.toStringAsFixed(1);
    setState(() {
      switch (run.kind) {
        case RunKind.solution when run.finished:
          _editor.keepSolution(run.moves);
          _status = 'solution kept: ${run.moves.length} moves, ${seconds}s';
        case RunKind.solution:
          _status = 'not kept: that take never reached the goal';
        case RunKind.wrongIdea when run.finished:
          _status =
              'that is not a wrong idea — it finishes the level in ${seconds}s. '
              'It is a second solution. Not kept.';
        case RunKind.wrongIdea when run.moves.isEmpty:
          _status = 'not kept: nothing was recorded';
        case RunKind.wrongIdea:
          _editor.keepWrongIdea(run.moves);
          _status =
              'wrong idea ${_editor.doc.wrongIdeas.length} kept: '
              '${run.moves.length} moves';
        case null:
          _status = run.finished
              ? 'the replay finished the level in ${seconds}s'
              : 'the replay did not finish the level';
      }
    });
  }

  // ——— files ———

  String get _json =>
      const JsonEncoder.withIndent('  ').convert(_level.toJson());

  Future<void> _save() async {
    final json = _json;
    await Clipboard.setData(ClipboardData(text: json));
    String where;
    try {
      where = await saveLevelFile(
        '${_editor.doc.id}.json',
        json,
        folder: widget.saveFolder,
      );
    } catch (error) {
      where = 'not saved as a file ($error)';
    }
    setState(() => _status = '$where · and copied to the clipboard');
  }

  Future<void> _openFile() async {
    final text = await pickLevelFile();
    if (text != null) _openText(text);
  }

  void _openText(String text) {
    try {
      final levels = levelsFromJson(
        jsonDecode(text),
        onSkipped: (skipped) => setState(() => _status = '$skipped'),
        // The bench: what is on trial opens here.
        accepts: Level.benchMechanics,
      );
      if (levels.isEmpty) {
        setState(() => _status = 'no level this build can play in that');
        return;
      }
      _startFrom(levels.first, keepId: true);
    } catch (error) {
      setState(() => _status = '$error');
    }
  }

  Future<void> _paste() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _PasteDialog(),
    );
    if (text != null && text.trim().isNotEmpty) _openText(text);
  }

  Future<void> _reread() async {
    try {
      final levels = await widget.onReread!();
      _extra = levels;
      final same = levels.where((l) => l.id == _editor.doc.id);
      if (same.isNotEmpty) _startFrom(same.first, keepId: true);
      setState(
        () => _status = '${levels.length} level(s) read · on ${_editor.doc.id}',
      );
    } catch (error) {
      setState(() => _status = '$error');
    }
  }

  /// Opens [level] in the editor. A campaign level is opened as a **copy**
  /// with a name of its own: the campaign is written in Dart and held by the
  /// tests, and the editor never writes to it.
  void _startFrom(Level level, {required bool keepId}) {
    final doc = EditorDoc.fromLevel(level);
    if (!keepId) doc.id = '${level.id}-copy';
    _editor.load(doc);
    _game.stop();
    _game.editCenter = null;
    _game.edit(_level);
  }

  // ——— the pointer ———

  Offset _world(Offset screen) {
    final at = _game.camera.globalToLocal(Vector2(screen.dx, screen.dy));
    return Offset(at.x, at.y);
  }

  double get _slop => 8 / _game.camera.viewfinder.zoom;

  void _down(PointerDownEvent event) {
    _gameFocus.requestFocus();
    if (!_editing) return;
    final pan = event.buttons & (kMiddleMouseButton | kSecondaryMouseButton);
    if (pan != 0 ||
        !_editor.pointerDown(_world(event.localPosition), slop: _slop)) {
      _panFrom = event.localPosition;
    }
  }

  void _move(PointerMoveEvent event) {
    if (!_editing) return;
    if (_panFrom case final from?) {
      final zoom = _game.camera.viewfinder.zoom;
      final by = (event.localPosition - from) / zoom;
      _panFrom = event.localPosition;
      final center = _game.editCenter;
      if (center != null) {
        _game.editCenter = center
          ..setValues(center.x - by.dx, center.y - by.dy);
      }
      return;
    }
    _editor.pointerMove(
      _world(event.localPosition),
      free: HardwareKeyboard.instance.isShiftPressed,
    );
  }

  void _up(PointerEvent event) {
    _panFrom = null;
    _editor.pointerUp();
  }

  void _scroll(PointerSignalEvent event) {
    if (!_editing || event is! PointerScrollEvent) return;
    final center = _game.editCenter;
    if (center == null) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) {
      final before = _world(event.localPosition);
      _game.editZoom = (_game.editZoom * exp(-event.scrollDelta.dy / 400))
          .clamp(0.1, 4.0);
      // Zoom about the pointer, not the middle of the screen.
      _game.camera.viewfinder.zoom = _game.editZoom;
      final after = _world(event.localPosition);
      center.setValues(
        center.x + before.dx - after.dx,
        center.y + before.dy - after.dy,
      );
      return;
    }
    final zoom = _game.camera.viewfinder.zoom;
    final sideways = keys.isShiftPressed
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    final down = keys.isShiftPressed ? 0.0 : event.scrollDelta.dy;
    center.setValues(center.x + sideways / zoom, center.y + down / zoom);
  }

  // ——— the keyboard ———

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Typing in a box is typing, not a shortcut.
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    final command = keys.isControlPressed || keys.isMetaPressed;

    if (key == LogicalKeyboardKey.tab) {
      _editing ? _play() : _toEdit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_editing) {
        _editor.select(null);
      } else {
        _toEdit();
      }
      return KeyEventResult.handled;
    }
    if (!_editing) return KeyEventResult.ignored;

    void Function()? action;
    if (command && key == LogicalKeyboardKey.keyZ) {
      action = keys.isShiftPressed ? _editor.redo : _editor.undo;
    } else if (command && key == LogicalKeyboardKey.keyY) {
      action = _editor.redo;
    } else if (command && key == LogicalKeyboardKey.keyC) {
      action = _editor.copySelected;
    } else if (command && key == LogicalKeyboardKey.keyV) {
      action = _editor.paste;
    } else if (command && key == LogicalKeyboardKey.keyD) {
      action = _editor.duplicateSelected;
    } else if (command && key == LogicalKeyboardKey.keyS) {
      action = _save;
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      action = _editor.deleteSelected;
    } else if (!command) {
      final fine = keys.isShiftPressed;
      final (dx, dy) = switch (key) {
        LogicalKeyboardKey.arrowLeft => (-1, 0),
        LogicalKeyboardKey.arrowRight => (1, 0),
        LogicalKeyboardKey.arrowUp => (0, -1),
        LogicalKeyboardKey.arrowDown => (0, 1),
        _ => (0, 0),
      };
      if (dx != 0 || dy != 0) action = () => _editor.nudge(dx, dy, fine: fine);
    }
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  // ——— the screen ———

  Offset get _viewCenter {
    final size = _game.size;
    return _world(Offset(size.x / 2, size.y * 0.7));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _key,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              onPointerSignal: _scroll,
              child: GameWidget<EditorGame>(
                game: _game,
                focusNode: _gameFocus,
                overlayBuilderMap: {
                  // Only while simply playing. Mid-recording the delay slider
                  // would change the level under a take, and the take would
                  // then be of a level nobody saved.
                  'controls': (context, game) => _mode != EditorMode.playing
                      ? const SizedBox.shrink()
                      : LabControls(
                          settings: game.settings,
                          onReload: game.reload,
                        ),
                },
                initialActiveOverlays: const ['controls'],
              ),
            ),
          ),
          // Clear of the game's own readout on the left and the level's name on
          // the right, both of which stay up while editing.
          Positioned(left: 264, top: 8, right: 240, child: _toolbar()),
          if (_editing)
            Positioned(
              right: 8,
              top: 96,
              bottom: 8,
              width: 290,
              child: _Inspector(editor: _editor, onReplay: _replay),
            ),
          if (_editing)
            Positioned(left: 8, bottom: 8, width: 420, child: _gatePanel()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    Widget button(
      IconData icon,
      String tip,
      VoidCallback? onPressed, {
      Color? color,
    }) => IconButton(
      tooltip: tip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
    );

    final running =
        _mode == EditorMode.recording || _mode == EditorMode.replaying;
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              button(Icons.edit, 'edit (Tab)', _editing ? null : _toEdit),
              button(
                Icons.play_arrow,
                'play it (Tab)',
                _mode == EditorMode.playing ? null : _play,
              ),
              button(
                Icons.fiber_manual_record,
                'record the solution — stops at the goal',
                running ? null : () => _record(RunKind.solution),
                color: const Color(0xFFE53935),
              ),
              button(
                Icons.radio_button_checked,
                'record a wrong idea — stop it when it has failed',
                running ? null : () => _record(RunKind.wrongIdea),
                color: const Color(0xFFFFA000),
              ),
              button(Icons.stop, 'stop (Esc)', _editing ? null : _toEdit),
              const _Gap(),
              button(
                Icons.undo,
                'undo (Ctrl+Z)',
                _editing && _editor.canUndo ? _editor.undo : null,
              ),
              button(
                Icons.redo,
                'redo (Ctrl+Shift+Z)',
                _editing && _editor.canRedo ? _editor.redo : null,
              ),
              const _Gap(),
              _startMenu(),
              if (canPickLevelFile)
                button(Icons.file_open, 'open a level file', _openFile),
              button(Icons.content_paste, 'paste a level as JSON', _paste),
              if (widget.onReread != null)
                button(
                  Icons.folder_open,
                  'read the levels back off the disk',
                  _reread,
                ),
              button(Icons.save_alt, 'save as JSON (Ctrl+S)', _save),
              if (widget.upload != null)
                button(
                  Icons.cloud_upload_outlined,
                  'send this level to be published',
                  () => UploadDialog.show(
                    context,
                    level: _level,
                    upload: widget.upload!,
                  ),
                ),
            ],
          ),
          if (_editing)
            Wrap(
              children: [
                for (final kind in PieceKind.values)
                  if (kind != PieceKind.goal)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: ActionChip(
                        label: Text('+ ${kind.label}'),
                        onPressed: () => _editor.add(kind, _viewCenter),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
              ],
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(_status!, style: _Style.status),
            ),
          if (running)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(
                '${_game.runSeconds.toStringAsFixed(1)}s',
                style: _Style.label,
              ),
            ),
        ],
      ),
    );
  }

  /// The menu's "nothing" entry. A real level rather than null: a popup menu
  /// takes a null answer to mean it was dismissed, and choosing it did
  /// nothing at all.
  static final Level _blank = EditorDoc.blank().toLevel();

  Widget _startMenu() => PopupMenuButton<Level>(
    tooltip: 'start from…',
    icon: const Icon(Icons.library_add, size: 20),
    onSelected: (level) => _startFrom(
      level,
      keepId: identical(level, _blank) || _extra.contains(level),
    ),
    itemBuilder: (context) => [
      PopupMenuItem(value: _blank, child: const Text('a blank level')),
      for (final level in _extra)
        PopupMenuItem(value: level, child: Text('${level.id} (from disk)')),
      PopupMenuItem(value: Levels.lab, child: const Text('the bench')),
      for (final level in Levels.bench)
        PopupMenuItem(
          value: level,
          child: Text('${level.id} · ${level.name} (on trial)'),
        ),
      for (final level in Levels.campaign)
        PopupMenuItem(value: level, child: Text('${level.id} · ${level.name}')),
    ],
  );

  Widget _gatePanel() {
    final verdict = _verdictFor == _editor.revision ? _verdict : null;
    final lines = <Widget>[];
    if (_numbers.isNotEmpty) {
      for (final finding in _numbers) {
        lines.add(_finding(finding));
      }
    } else if (verdict == null) {
      lines.add(
        Text(
          _checking ? 'replaying…' : 'the numbers pass · replaying soon',
          style: _Style.label,
        ),
      );
    } else if (verdict.accepted) {
      lines.add(
        const Text(
          'OK — the gate would take this',
          style: TextStyle(color: Color(0xFF81C784), fontSize: 13),
        ),
      );
    } else {
      // The cheap runs first: a level that falls to holding one arrow is the
      // failure nobody is looking for.
      final findings = [...verdict.findings]
        ..sort(
          (a, b) =>
              (b.refusal == Refusal.cheapRunFinishes ? 1 : 0) -
              (a.refusal == Refusal.cheapRunFinishes ? 1 : 0),
        );
      lines.addAll(findings.map(_finding));
    }
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('the gate', style: _Style.heading),
            const SizedBox(height: 4),
            ...lines,
          ],
        ),
      ),
    );
  }

  Widget _finding(Finding finding) {
    final cheap = finding.refusal == Refusal.cheapRunFinishes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '× ${finding.detail}',
        style: TextStyle(
          color: cheap ? const Color(0xFFFFB74D) : const Color(0xFFEF9A9A),
          fontWeight: cheap ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

/// The right-hand panel: whatever is selected, or the level itself, and its
/// recorded runs.
class _Inspector extends StatelessWidget {
  const _Inspector({required this.editor, required this.onReplay});

  final EditorController editor;
  final void Function(List<Move> moves, String what) onReplay;

  EditorDoc get doc => editor.doc;

  @override
  Widget build(BuildContext context) {
    final piece = editor.selected;
    return _Card(
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          if (piece != null) ..._piece(piece),
          if (editor.spawnSelected) ..._spawn(),
          if (piece == null && !editor.spawnSelected) ..._level(),
          const Divider(),
          ..._runs(),
        ],
      ),
    );
  }

  List<Widget> _piece(Piece piece) {
    final r = piece.rect;
    void rect(Rect next) => editor.setRect(piece, next, group: (piece, 'rect'));
    double? n(String text) => double.tryParse(text.trim());
    return [
      Text(piece.kind.label, style: _Style.heading),
      _Row(
        children: [
          _Field(
            label: 'x',
            value: _num(r.left),
            id: (piece, 'x'),
            onChanged: (t) => n(t) == null
                ? null
                : rect(Rect.fromLTWH(n(t)!, r.top, r.width, r.height)),
          ),
          _Field(
            label: 'y',
            value: _num(r.top),
            id: (piece, 'y'),
            onChanged: (t) => n(t) == null
                ? null
                : rect(Rect.fromLTWH(r.left, n(t)!, r.width, r.height)),
          ),
        ],
      ),
      _Row(
        children: [
          _Field(
            label: 'width',
            value: _num(r.width),
            id: (piece, 'w'),
            onChanged: (t) => n(t) == null
                ? null
                : rect(Rect.fromLTWH(r.left, r.top, n(t)!, r.height)),
          ),
          _Field(
            label: 'height',
            value: _num(r.height),
            id: (piece, 'h'),
            onChanged: (t) => n(t) == null
                ? null
                : rect(Rect.fromLTWH(r.left, r.top, r.width, n(t)!)),
          ),
        ],
      ),
      if (piece.kind == PieceKind.door) ...[
        _Field(
          label: 'name',
          value: piece.doorId,
          id: (piece, 'id'),
          onChanged: (t) => t.trim().isEmpty
              ? null
              : editor.edit(
                  (doc) => doc.renameDoor(piece, t.trim()),
                  group: (piece, 'id'),
                ),
        ),
        _Field(
          label: 'stays open after, seconds',
          value: _num(piece.linger),
          id: (piece, 'linger'),
          onChanged: (t) => n(t) == null
              ? null
              : editor.edit((_) => piece.linger = n(t)!, group: (piece, 'l')),
        ),
      ],
      if (piece.kind.links) ...[
        Row(
          children: [
            Text(
              piece.kind == PieceKind.plate ? 'opens ' : 'flips ',
              style: _Style.label,
            ),
            DropdownButton<String>(
              value: piece.link,
              isDense: true,
              items: [
                for (final id in {Piece.noDoor, ...doc.doorIds})
                  DropdownMenuItem(value: id, child: Text(id)),
              ],
              onChanged: (id) =>
                  id == null ? null : editor.edit((_) => piece.link = id),
            ),
          ],
        ),
        if (piece.kind == PieceKind.plate)
          _Switch(
            label: 'holds it shut instead',
            value: piece.inverts,
            onChanged: (v) => editor.edit((_) => piece.inverts = v),
          ),
      ],
      const SizedBox(height: 8),
      if (doc.canRemove(piece))
        Wrap(
          spacing: 6,
          children: [
            OutlinedButton(
              onPressed: editor.duplicateSelected,
              child: const Text('duplicate'),
            ),
            OutlinedButton(
              onPressed: editor.deleteSelected,
              child: const Text('delete'),
            ),
          ],
        ),
    ];
  }

  List<Widget> _spawn() => [
    const Text('the start', style: _Style.heading),
    _Row(
      children: [
        _Field(
          label: 'x',
          value: _num(doc.spawnX),
          id: 'spawnX',
          onChanged: (t) => double.tryParse(t) == null
              ? null
              : editor.edit(
                  (doc) => doc.spawnX = double.parse(t),
                  group: 'spawnX',
                ),
        ),
        _Field(
          label: 'feet at',
          value: _num(doc.floorTop),
          id: 'floorTop',
          onChanged: (t) => double.tryParse(t) == null
              ? null
              : editor.edit(
                  (doc) => doc.floorTop = double.parse(t),
                  group: 'floorTop',
                ),
        ),
      ],
    ),
  ];

  List<Widget> _level() {
    final two = doc.delays.length > 1;
    return [
      const Text('the level', style: _Style.heading),
      _Field(
        label: 'id',
        value: doc.id,
        id: 'id',
        onChanged: (t) => t.trim().isEmpty
            ? null
            : editor.edit((doc) => doc.id = t.trim(), group: 'id'),
      ),
      _Field(
        label: 'name',
        value: doc.name,
        id: 'name',
        rtl: true,
        onChanged: (t) => t.trim().isEmpty
            ? null
            : editor.edit((doc) => doc.name = t, group: 'name'),
      ),
      _Field(
        label: 'teaches',
        value: doc.teaches,
        id: 'teaches',
        rtl: true,
        onChanged: (t) => t.trim().isEmpty
            ? null
            : editor.edit((doc) => doc.teaches = t, group: 'teaches'),
      ),
      // English, for a player whose device does not ask for Arabic. Empty
      // means none, and the Arabic is shown to everyone.
      _Field(
        label: 'name (en)',
        value: doc.nameEn ?? '',
        id: 'nameEn',
        onChanged: (t) => editor.edit(
          (doc) => doc.nameEn = t.trim().isEmpty ? null : t,
          group: 'nameEn',
        ),
      ),
      _Field(
        label: 'teaches (en)',
        value: doc.teachesEn ?? '',
        id: 'teachesEn',
        onChanged: (t) => editor.edit(
          (doc) => doc.teachesEn = t.trim().isEmpty ? null : t,
          group: 'teachesEn',
        ),
      ),
      _Row(
        children: [
          for (final (i, delay) in doc.delays.indexed)
            _Field(
              label: i == 0 ? 'delay, s' : 'far delay, s',
              value: _num(delay),
              id: ('delay', i, doc.delays.length),
              onChanged: (t) => double.tryParse(t) == null
                  ? null
                  : editor.edit(
                      (doc) =>
                          doc.delays = [...doc.delays]..[i] = double.parse(t),
                      group: ('delay', i),
                    ),
            ),
        ],
      ),
      TextButton(
        onPressed: () => editor.edit(
          (doc) => doc.delays = two
              ? [doc.delays.first]
              : [doc.delays.first, doc.delays.first + 4],
        ),
        child: Text(two ? 'one shadow' : 'a second shadow'),
      ),
      _Switch(
        label: 'shadow kills',
        value: doc.shadowKills,
        onChanged: (v) => editor.edit((doc) => doc.shadowKills = v),
      ),
      _Switch(
        label: 'shadow is solid',
        value: doc.shadowIsSolid,
        onChanged: (v) => editor.edit((doc) => doc.shadowIsSolid = v),
      ),
      _Switch(
        label: 'solid only where ducked',
        value: doc.solidWhen == ShadowSolidity.crouched,
        onChanged: (v) => editor.edit(
          (doc) => doc.solidWhen = v
              ? ShadowSolidity.crouched
              : ShadowSolidity.always,
        ),
      ),
    ];
  }

  List<Widget> _runs() {
    String length(List<Move> run) =>
        '${run.fold<double>(0, (s, m) => s + m.seconds).toStringAsFixed(1)}s';
    return [
      const Text('recorded runs', style: _Style.heading),
      if (doc.solution.isEmpty)
        const Text(
          'no solution yet — record one, and finish the level',
          style: _Style.label,
        )
      else
        _RunRow(
          label: 'solution · ${length(doc.solution)}',
          onPlay: () => onReplay(doc.solution, 'the solution'),
          onDrop: editor.dropSolution,
        ),
      if (doc.wrongIdeas.isEmpty)
        const Text(
          'no wrong idea yet — record the obvious thing that should not work',
          style: _Style.label,
        ),
      for (final (i, idea) in doc.wrongIdeas.indexed)
        _RunRow(
          label: 'wrong idea ${i + 1} · ${length(idea)}',
          onPlay: () => onReplay(idea, 'wrong idea ${i + 1}'),
          onDrop: () => editor.dropWrongIdea(i),
        ),
    ];
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.label,
    required this.onPlay,
    required this.onDrop,
  });

  final String label;
  final VoidCallback onPlay;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: _Style.label)),
      IconButton(
        tooltip: 'replay it as the gate would',
        onPressed: onPlay,
        icon: const Icon(Icons.play_circle_outline, size: 18),
      ),
      IconButton(
        tooltip: 'throw it away',
        onPressed: onDrop,
        icon: const Icon(Icons.close, size: 18),
      ),
    ],
  );
}

/// A text box that follows its value while you are not typing in it, and
/// leaves you alone while you are.
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.id,
    required this.onChanged,
    this.rtl = false,
  });

  final String label;
  final String value;

  /// What the box is for. A different id is a different box.
  final Object id;
  final void Function(String text) onChanged;
  final bool rtl;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(_Field old) {
    super.didUpdateWidget(old);
    if ((old.id != widget.id || !_focus.hasFocus) &&
        _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextField(
      controller: _text,
      focusNode: _focus,
      textDirection: widget.rtl ? TextDirection.rtl : null,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: child),
      ],
    ],
  );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: _Style.label)),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE6202020),
    borderRadius: BorderRadius.circular(8),
    child: child,
  );
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 12);
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('paste a level'),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 14,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          hintText: '{ "id": …, "blocks": […], … }',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('open'),
      ),
    ],
  );
}

abstract final class _Style {
  static const heading = TextStyle(
    color: Color(0xFFEDEDED),
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const label = TextStyle(color: Color(0xFFBDBDBD), fontSize: 12);
  static const status = TextStyle(
    color: Color(0xFFE8B96A),
    fontSize: 12,
    height: 1.4,
  );
}
