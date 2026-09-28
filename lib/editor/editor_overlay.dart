import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'editor.dart';
import 'editor_doc.dart';
import 'editor_game.dart';
import 'editor_rules.dart';

/// What the editor draws over the level: outlines, handles, the lines from
/// plates to their doors, and the rules (`docs/phase-9-editor.md` §٤).
///
/// On the camera's viewfinder rather than in the world, so it is drawn in
/// world units in front of the level and survives the world being emptied
/// and rebuilt on every edit. Only while editing: in play the level looks
/// like the level, with nothing of the editor on it.
class EditorOverlay extends Component {
  EditorOverlay({required this.game, required this.editor})
    : super(priority: 10000);

  final EditorGame game;
  final EditorController editor;

  DrawnRules? _rules;
  int _rulesFor = -1;

  DrawnRules get rules {
    if (_rulesFor != editor.revision || _rules == null) {
      _rules = DrawnRules.of(editor.level);
      _rulesFor = editor.revision;
    }
    return _rules!;
  }

  static const Color _outline = Color(0x6619324F);
  static const Color _selected = Color(0xFF1E88E5);
  static const Color _bad = Color(0xFFE53935);
  static const Color _reach = Color(0x5519324F);
  static const Color _climbable = Color(0xFFFFA000);
  static const Color _link = Color(0xCC1565C0);

  @override
  void render(Canvas canvas) {
    if (game.mode != EditorMode.editing) return;
    final zoom = game.camera.viewfinder.zoom;
    final px = 1 / (zoom <= 0 ? 1 : zoom);
    final doc = editor.doc;
    final rules = this.rules;

    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * px
      ..color = color;

    // The staircase: over every open ledge, how high your past lifts you.
    final reach = stroke(_reach, 1);
    for (final ledge in rules.ledges) {
      _dashed(
        canvas,
        Offset(ledge.left, ledge.y - rules.reach),
        Offset(ledge.right, ledge.y - rules.reach),
        reach,
        8 * px,
      );
    }
    // And every ledge that staircase puts in reach from somewhere lower.
    final climbable = stroke(_climbable, 3);
    for (final ledge in rules.climbable) {
      canvas.drawLine(
        Offset(ledge.left, ledge.y),
        Offset(ledge.right, ledge.y),
        climbable,
      );
    }

    // Everything, outlined — lights and markers have no body to see.
    for (final piece in doc.pieces) {
      final bad =
          (piece.kind == PieceKind.door &&
              rules.shortDoors.contains(piece.doorId)) ||
          (piece.kind.links && rules.danglingLinks.contains(piece.rect));
      canvas.drawRect(piece.rect, stroke(bad ? _bad : _outline, bad ? 2.5 : 1));
    }

    // Plates and keys to their doors.
    final doors = {
      for (final p in doc.pieces)
        if (p.kind == PieceKind.door) p.doorId: p,
    };
    for (final piece in doc.pieces) {
      if (!piece.kind.links) continue;
      final door = doors[piece.link];
      final from = piece.rect.topCenter;
      if (door == null) {
        // Cut short and red: pointing at nothing.
        _dashed(
          canvas,
          from,
          from + const Offset(0, -60),
          stroke(_bad, 2),
          5 * px,
        );
        continue;
      }
      _dashed(
        canvas,
        from,
        door.rect.center,
        stroke(piece.inverts ? _bad.withValues(alpha: 0.7) : _link, 1.5),
        6 * px,
      );
    }

    // The start.
    canvas.drawRect(
      doc.spawnBox,
      stroke(
        rules.spawnInside
            ? _bad
            : (editor.spawnSelected ? _selected : _outline),
        rules.spawnInside || editor.spawnSelected ? 2.5 : 1,
      ),
    );

    // The selection and its handles.
    if (editor.selected case final piece?) {
      canvas.drawRect(piece.rect, stroke(_selected, 2));
      final handle = Paint()..color = _selected;
      final r = piece.rect;
      for (final at in [
        r.topLeft,
        r.topCenter,
        r.topRight,
        r.centerLeft,
        r.centerRight,
        r.bottomLeft,
        r.bottomCenter,
        r.bottomRight,
      ]) {
        canvas.drawRect(
          Rect.fromCenter(center: at, width: 7 * px, height: 7 * px),
          handle,
        );
      }
    }
  }

  static void _dashed(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
  ) {
    final length = (to - from).distance;
    if (length <= 0 || dash <= 0) return;
    final step = (to - from) / length;
    // Past a few thousand dashes the line is a line; draw it as one.
    if (length / dash > 2000) {
      canvas.drawLine(from, to, paint);
      return;
    }
    for (var d = 0.0; d < length; d += dash * 2) {
      canvas.drawLine(
        from + step * d,
        from + step * min(d + dash, length),
        paint,
      );
    }
  }
}
