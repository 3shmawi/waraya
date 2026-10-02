// The editor's model, with no game and no screen.
//
// The first promise is the one everything else stands on: a level opened in
// the editor and saved without touching it is the level that was opened —
// every number, every list in the same order. An editor that nudged a door by
// a rounding error on the way through would be an editor that quietly breaks
// the campaign levels people start from.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/editor/editor_rules.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

String _json(Level level) => jsonEncode(level.toJson());

void main() {
  group('a level through the editor', () {
    for (final level in [...Levels.campaign, ...Levels.bench, Levels.lab]) {
      test('${level.id} comes out exactly as it went in', () {
        final doc = EditorDoc.fromLevel(level);
        expect(_json(doc.toLevel()), _json(level));
        // And through JSON, which is how it leaves the editor — read back the
        // way the bench reads, so a level on trial comes back with it.
        final back = levelFromJson(
          jsonDecode(_json(doc.toLevel())),
          accepts: Level.benchMechanics,
        );
        expect(_json(EditorDoc.fromLevel(back).toLevel()), _json(level));
      });
    }

    test('a copy is a copy, not the same pieces', () {
      final doc = EditorDoc.fromLevel(Levels.standOnYourself);
      final copy = doc.copy();
      copy.pieces.first.rect = Rect.zero;
      expect(doc.pieces.first.rect, isNot(Rect.zero));
    });

    test('a blank page is a level the game can put up', () {
      final level = EditorDoc.blank().toLevel();
      expect(level.blocks, isNotEmpty);
      expect(spawnsInside(level), isFalse);
    });
  });

  group('putting things in', () {
    test('a new door is never one you can climb', () {
      final doc = EditorDoc.blank();
      final door = doc.add(PieceKind.door, const Offset(200, 620));
      expect(door.rect.height, greaterThanOrEqualTo(Levels.minDoorHeight));
      expect(door.rect.bottom, 620, reason: 'it stands on the floor');
    });

    test('a new plate points at the nearest door', () {
      final doc = EditorDoc.blank();
      doc.add(PieceKind.door, const Offset(-600, 620));
      final near = doc.add(PieceKind.door, const Offset(300, 620));
      final plate = doc.add(PieceKind.plate, const Offset(200, 620));
      expect(plate.link, near.doorId);
      expect(doc.doorIds.toSet().length, 2, reason: 'two doors, two names');
    });

    test('with no door, a plate points at nothing the check will name', () {
      final doc = EditorDoc.blank();
      doc.add(PieceKind.plate, const Offset(200, 620));
      final findings = checkNumbers(doc.toLevel());
      expect(
        findings.map((f) => f.detail),
        contains(contains('which is not a door')),
      );
    });

    test('renaming a door takes its plates with it', () {
      final doc = EditorDoc.fromLevel(Levels.pressItEarly);
      final door = doc.pieces.firstWhere((p) => p.kind == PieceKind.door);
      doc.renameDoor(door, 'front');
      final level = doc.toLevel();
      expect(level.doors.single.id, 'front');
      expect(level.plates.single.opens, 'front');
    });

    test('the goal cannot be removed, or copied into two', () {
      final doc = EditorDoc.blank();
      final goal = doc.pieces.firstWhere((p) => p.kind == PieceKind.goal);
      expect(doc.canRemove(goal), isFalse);
    });

    test('a plate on a floor is picked before the floor', () {
      final doc = EditorDoc.fromLevel(Levels.pressItEarly);
      final plate = doc.pieces.firstWhere((p) => p.kind == PieceKind.plate);
      expect(doc.pieceAt(plate.rect.center), same(plate));
    });
  });

  group('the controller', () {
    EditorController fresh() =>
        EditorController(EditorDoc.fromLevel(Levels.pressItEarly));

    test(
      'a drag moves by whole grid squares and keeps a plate on its floor',
      () {
        final editor = fresh();
        final plate = editor.doc.pieces.firstWhere(
          (p) => p.kind == PieceKind.plate,
        );
        final was = plate.rect;
        expect(editor.pointerDown(was.center, slop: 2), isTrue);
        editor.pointerMove(was.center + const Offset(33, 4));
        editor.pointerUp();
        expect(plate.rect.left, was.left + 30);
        expect(plate.rect.top, was.top, reason: '4 snaps to nothing');
        expect(plate.rect.size, was.size);
      },
    );

    test('Shift drags to the unit', () {
      final editor = fresh();
      final plate = editor.doc.pieces.firstWhere(
        (p) => p.kind == PieceKind.plate,
      );
      final was = plate.rect;
      editor.pointerDown(was.center, slop: 2);
      editor.pointerMove(was.center + const Offset(33, 0), free: true);
      editor.pointerUp();
      expect(plate.rect.left, was.left + 33);
    });

    test('an edge drags on its own and snaps to the grid', () {
      final editor = fresh();
      final door = editor.doc.pieces.firstWhere(
        (p) => p.kind == PieceKind.door,
      );
      editor.select(door);
      final was = door.rect;
      final grip = Offset(was.center.dx, was.top);
      editor.pointerDown(grip, slop: 4);
      editor.pointerMove(grip + const Offset(0, 47));
      editor.pointerUp();
      expect(door.rect.top, EditorController.snap(was.top + 47));
      expect(door.rect.bottom, was.bottom);
      expect(door.rect.left, was.left);
    });

    test('one drag is one undo, however many frames it took', () {
      final editor = fresh();
      final before = _json(editor.level);
      final plate = editor.doc.pieces.firstWhere(
        (p) => p.kind == PieceKind.plate,
      );
      editor.pointerDown(plate.rect.center, slop: 2);
      for (var i = 1; i <= 20; i++) {
        editor.pointerMove(plate.rect.center + Offset(i * 10.0, 0));
      }
      editor.pointerUp();
      expect(_json(editor.level), isNot(before));
      editor.undo();
      expect(_json(editor.level), before);
      editor.redo();
      expect(_json(editor.level), isNot(before));
    });

    test('the start drags too, and is not a piece', () {
      final editor = fresh();
      final start = editor.doc.spawnBox.center;
      expect(editor.pointerDown(start, slop: 2), isTrue);
      expect(editor.spawnSelected, isTrue);
      editor.pointerMove(start + const Offset(-100, 0));
      editor.pointerUp();
      expect(editor.doc.spawnX, Levels.pressItEarly.spawnX - 100);
    });

    test('empty space selects nothing, so the view can pan', () {
      final editor = fresh();
      expect(editor.pointerDown(const Offset(0, -3000), slop: 2), isFalse);
      expect(editor.selected, isNull);
    });

    test('a pasted door gets a name of its own', () {
      final editor = fresh();
      final door = editor.doc.pieces.firstWhere(
        (p) => p.kind == PieceKind.door,
      );
      editor
        ..select(door)
        ..duplicateSelected();
      expect(editor.doc.doorIds.toSet().length, 2);
    });

    test('runs are kept, and wrong ideas can be let go one at a time', () {
      final editor = EditorController(EditorDoc.blank());
      editor.keepSolution(const [Move.right(3)]);
      editor.keepWrongIdea(const [Move.left(3)]);
      editor.keepWrongIdea(const [Move(3)]);
      editor.dropWrongIdea(0);
      final level = editor.level;
      expect(level.solution, const [Move.right(3)]);
      expect(level.wrongIdeas, const [
        [Move(3)],
      ]);
    });
  });

  group('the drawn rules are the gate\'s rules', () {
    Level withDoor(double height, {List<double> delays = const [3]}) {
      final doc = EditorDoc.blank()..delays = delays;
      doc.add(PieceKind.door, const Offset(300, 620)).rect = Rect.fromLTRB(
        290,
        620 - height,
        316,
        620,
      );
      return doc.toLevel();
    }

    bool gateSaysShort(Level level) => checkNumbers(
      level,
    ).any((f) => f.detail.contains('a body on a shadow at its foot'));

    for (final (height, delays) in [
      (Levels.minDoorHeight - 1, [3.0]),
      (Levels.minDoorHeight, [3.0]),
      (Levels.minDoorHeightTwoShadows - 1, [2.0, 5.0]),
      (Levels.minDoorHeightTwoShadows, [2.0, 5.0]),
    ]) {
      test('a door $height tall with ${delays.length} shadow(s)', () {
        final level = withDoor(height, delays: delays);
        expect(
          DrawnRules.of(level).shortDoors.isNotEmpty,
          gateSaysShort(level),
        );
      });
    }

    test('the reach is the campaign\'s numbers', () {
      expect(
        DrawnRules.of(EditorDoc.blank().toLevel()).reach,
        Levels.crouchedLadderReach,
      );
      final two = EditorDoc.blank()..delays = [2, 5];
      expect(DrawnRules.of(two.toLevel()).reach, closeTo(274, 1));
      final always = EditorDoc.blank()..solidWhen = ShadowSolidity.always;
      expect(DrawnRules.of(always.toLevel()).reach, Levels.ladderReach);
    });

    test('a start inside a wall is red where the gate refuses it', () {
      final doc = EditorDoc.blank()..floorTop = 700;
      final level = doc.toLevel();
      expect(DrawnRules.of(level).spawnInside, isTrue);
      expect(
        checkNumbers(level).map((f) => f.detail),
        contains('the player spawns inside the scenery'),
      );
    });

    test('a shelf a crouch too high is not climbable; one lower is', () {
      Level shelfAt(double height) {
        final doc = EditorDoc.blank();
        doc.add(PieceKind.block, const Offset(0, 0)).rect = Rect.fromLTRB(
          200,
          620 - height,
          500,
          620 - height + 30,
        );
        return doc.toLevel();
      }

      bool climbs(Level level) =>
          DrawnRules.of(level).climbable.any((ledge) => ledge.y < 620);
      expect(climbs(shelfAt(190)), isTrue);
      expect(climbs(shelfAt(210)), isFalse);
    });

    test('a floor with a wall standing on it is open either side only', () {
      final ledges = DrawnRules.openLedges(const [
        Rect.fromLTRB(0, 620, 1000, 700),
        Rect.fromLTRB(400, 300, 440, 620),
      ]);
      expect(ledges.where((l) => l.y == 620).map((l) => (l.left, l.right)), [
        (0.0, 400.0),
        (440.0, 1000.0),
      ]);
    });
  });
}
