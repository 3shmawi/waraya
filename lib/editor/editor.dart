import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../level/level.dart';
import '../level/playthrough.dart';
import 'editor_doc.dart';

/// Which edges of a rectangle a drag is moving. All four is a move.
class Edges {
  const Edges({
    this.left = false,
    this.top = false,
    this.right = false,
    this.bottom = false,
  });

  static const all = Edges(left: true, top: true, right: true, bottom: true);

  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  bool get isMove => left && top && right && bottom;
  bool get isNone => !left && !top && !right && !bottom;
}

/// Everything the editor does to a level, with no screen attached.
///
/// Pointer positions come in already in world units; the view does the
/// camera's arithmetic and nothing else. So every edit the editor can make —
/// select, drag, resize, snap, undo, paste — is a method call a test can
/// make, and the view is only a way of making them with a mouse.
class EditorController extends ChangeNotifier {
  EditorController(this._doc);

  EditorDoc get doc => _doc;
  EditorDoc _doc;

  /// Bumped on every change to the level, so the view knows to rebuild the
  /// game and re-check it.
  int get revision => _revision;
  int _revision = 0;

  /// The grid everything snaps to, in world units. Shift unsnaps.
  static const double grid = 10;

  /// The piece being inspected and dragged, or null.
  Piece? get selected => _selected;
  Piece? _selected;

  /// True while the player's start, rather than a piece, is selected.
  bool get spawnSelected => _spawnSelected;
  bool _spawnSelected = false;

  final List<EditorDoc> _undo = [];
  final List<EditorDoc> _redo = [];
  Object? _lastGroup;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  Piece? _clipboard;
  bool get hasClipboard => _clipboard != null;

  /// The level as it stands.
  Level get level => _doc.toLevel();

  // ——— changes ———

  /// Makes a change that can be undone.
  ///
  /// [group] folds a run of changes into one undo step — every keystroke in
  /// a name, every frame of a drag — so undo takes back the edit, not the
  /// last letter of it.
  void edit(void Function(EditorDoc doc) change, {Object? group}) {
    if (group == null || group != _lastGroup) {
      _undo.add(_doc.copy());
      if (_undo.length > 200) _undo.removeAt(0);
      _redo.clear();
    }
    _lastGroup = group;
    change(_doc);
    _changed();
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }

  /// Starts again from [doc] — a campaign level, a file, a blank page. Can
  /// be undone like anything else.
  void load(EditorDoc doc) {
    _undo.add(_doc);
    _redo.clear();
    _lastGroup = null;
    _doc = doc;
    _clearSelection();
    _changed();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_doc);
    _doc = _undo.removeLast();
    _lastGroup = null;
    _clearSelection();
    _changed();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_doc);
    _doc = _redo.removeLast();
    _lastGroup = null;
    _clearSelection();
    _changed();
  }

  /// Ends a run of grouped edits, so the next one is its own undo step.
  void seal() => _lastGroup = null;

  // ——— selection ———

  void select(Piece? piece) {
    _selected = piece;
    _spawnSelected = false;
    seal();
    notifyListeners();
  }

  void selectSpawn() {
    _selected = null;
    _spawnSelected = true;
    seal();
    notifyListeners();
  }

  void _clearSelection() {
    _selected = null;
    _spawnSelected = false;
  }

  // ——— pieces ———

  /// Adds a [kind] standing on [at], snapped, and selects it.
  void add(PieceKind kind, Offset at) {
    late Piece added;
    edit((doc) => added = doc.add(kind, Offset(snap(at.dx), snap(at.dy))));
    select(added);
  }

  void deleteSelected() {
    final piece = _selected;
    if (piece == null || !_doc.canRemove(piece)) return;
    edit((doc) => doc.pieces.remove(piece));
    select(null);
  }

  void copySelected() {
    final piece = _selected;
    if (piece == null || !_doc.canRemove(piece)) return;
    _clipboard = piece.copy();
    notifyListeners();
  }

  /// Puts a copy of what was copied down a little way off the original — or
  /// at [at], when there is somewhere to put it.
  void paste({Offset? at}) {
    final source = _clipboard;
    if (source == null) return;
    final piece = source.copy();
    piece.rect = at == null
        ? piece.rect.shift(const Offset(grid * 4, -grid * 4))
        : piece.rect.shift(
            Offset(
              snap(at.dx) - piece.rect.center.dx,
              snap(at.dy) - piece.rect.bottom,
            ),
          );
    // Two doors with one name are two doors one plate cannot tell apart.
    if (piece.kind == PieceKind.door) piece.doorId = _doc.freshDoorId();
    edit((doc) => doc.pieces.add(piece));
    // The next paste lands further along, not on top of this one.
    _clipboard = piece.copy();
    select(piece);
  }

  void duplicateSelected() {
    copySelected();
    paste();
  }

  /// Moves the selection by whole grid squares, or single units with [fine].
  void nudge(int dx, int dy, {bool fine = false}) {
    final step = fine ? 1.0 : grid;
    final by = Offset(dx * step, dy * step);
    if (_spawnSelected) {
      edit((doc) {
        doc.spawnX += by.dx;
        doc.floorTop += by.dy;
      }, group: #nudge);
    } else if (_selected case final piece?) {
      edit((doc) => piece.rect = piece.rect.shift(by), group: #nudge);
    }
  }

  /// Sets the selected piece's rectangle outright, from the inspector.
  void setRect(Piece piece, Rect rect, {Object? group}) {
    if (rect.width <= 0 || rect.height <= 0) return;
    edit((doc) => piece.rect = rect, group: group);
  }

  // ——— runs ———

  /// Keeps [moves] as the level's recorded solution.
  void keepSolution(List<Move> moves) => edit((doc) => doc.solution = moves);

  /// Keeps [moves] as one more recorded wrong idea.
  void keepWrongIdea(List<Move> moves) =>
      edit((doc) => doc.wrongIdeas = [...doc.wrongIdeas, moves]);

  void dropWrongIdea(int index) =>
      edit((doc) => doc.wrongIdeas = [...doc.wrongIdeas]..removeAt(index));

  void dropSolution() => edit((doc) => doc.solution = const []);

  // ——— dragging ———

  _Drag? _drag;

  /// True while a drag is moving something.
  bool get dragging => _drag != null;

  /// A press at [at]. Picks up a handle of the selection, the selection, a
  /// piece, or the player's start, in that order. Returns false if there is
  /// nothing there, so the view can pan the camera instead.
  ///
  /// [slop] is how near an edge counts as on it, in world units — the view
  /// works it out from the zoom, so a handle is the same size on screen
  /// however far out you are.
  bool pointerDown(Offset at, {required double slop}) {
    final selected = _selected;
    if (selected != null) {
      final edges = edgesNear(selected.rect, at, slop);
      if (!edges.isNone) {
        _drag = _Drag.piece(selected, edges, at);
        return true;
      }
    }
    if (_doc.spawnBox.inflate(slop / 2).contains(at)) {
      selectSpawn();
      _drag = _Drag.spawn(_doc.spawnX, _doc.floorTop, at);
      return true;
    }
    final piece = _doc.pieceAt(at, slop: slop / 2);
    if (piece != null) {
      select(piece);
      _drag = _Drag.piece(piece, Edges.all, at);
      return true;
    }
    select(null);
    return false;
  }

  /// The pointer moved to [at]. [free] is Shift: no snapping.
  void pointerMove(Offset at, {bool free = false}) {
    final drag = _drag;
    if (drag == null) return;
    final delta = at - drag.from;
    if (!drag.moved && delta.distance < 1) return;
    drag.moved = true;

    if (drag.piece case final piece?) {
      final next = _dragged(drag.rect!, drag.edges, delta, free);
      edit((doc) => piece.rect = next, group: drag);
    } else {
      final x = free
          ? drag.spawnX! + delta.dx
          : _snapDelta(drag.spawnX!, delta.dx);
      final y = free
          ? drag.floorTop! + delta.dy
          : snap(drag.floorTop! + delta.dy);
      edit((doc) {
        doc.spawnX = x;
        doc.floorTop = y;
      }, group: drag);
    }
  }

  void pointerUp() {
    _drag = null;
    seal();
  }

  /// What [rect] becomes when its [edges] are dragged by [delta].
  ///
  /// A move snaps the **distance**, not the position, so a plate sitting at
  /// 608 on a floor at 620 stays sitting on the floor however far it is
  /// dragged. A resize snaps the edge being dragged to the grid, because an
  /// edge is what lines up with other edges.
  static Rect _dragged(Rect rect, Edges edges, Offset delta, bool free) {
    if (edges.isMove) {
      final dx = free ? delta.dx : snap(delta.dx);
      final dy = free ? delta.dy : snap(delta.dy);
      return rect.shift(Offset(dx, dy));
    }
    double at(double edge, double by) => free ? edge + by : snap(edge + by);
    final least = free ? 2.0 : grid;
    var left = edges.left ? at(rect.left, delta.dx) : rect.left;
    var right = edges.right ? at(rect.right, delta.dx) : rect.right;
    var top = edges.top ? at(rect.top, delta.dy) : rect.top;
    var bottom = edges.bottom ? at(rect.bottom, delta.dy) : rect.bottom;
    if (edges.left) left = min(left, right - least);
    if (edges.right) right = max(right, left + least);
    if (edges.top) top = min(top, bottom - least);
    if (edges.bottom) bottom = max(bottom, top + least);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static double _snapDelta(double from, double by) => from + snap(by);

  static double snap(double value) => (value / grid).round() * grid;

  /// Which edges of [rect] [at] is within [slop] of. None when it is not on
  /// the border at all.
  static Edges edgesNear(Rect rect, Offset at, double slop) {
    if (!rect.inflate(slop).contains(at)) return const Edges();
    // A rectangle thinner than two handles is all border; let the middle of it
    // be a move, not a resize nobody can grab the other side of.
    final tall = rect.height > slop * 3;
    final wide = rect.width > slop * 3;
    return Edges(
      left: wide && (at.dx - rect.left).abs() <= slop,
      right: wide && (at.dx - rect.right).abs() <= slop,
      top: tall && (at.dy - rect.top).abs() <= slop,
      bottom: tall && (at.dy - rect.bottom).abs() <= slop,
    );
  }
}

class _Drag {
  _Drag.piece(Piece this.piece, this.edges, this.from)
    : rect = piece.rect,
      spawnX = null,
      floorTop = null;

  _Drag.spawn(double this.spawnX, double this.floorTop, this.from)
    : piece = null,
      rect = null,
      edges = Edges.all;

  final Piece? piece;
  final Rect? rect;
  final Edges edges;
  final double? spawnX;
  final double? floorTop;
  final Offset from;
  bool moved = false;
}
