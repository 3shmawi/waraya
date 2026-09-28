// Sending a level from the bench, with no server.
//
// The one thing that matters most here is the thing that does not happen: a
// level the gate would refuse never reaches the backend at all.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_upload.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/ui/upload_dialog.dart';

class FakeBackend implements LevelBackend {
  @override
  String? signedInAs;

  final sent = <String, Map<String, Object?>>{};
  final codes = <String>[];
  Object? refuseWith;

  @override
  Future<void> sendCode(String email) async => codes.add(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != '123456') throw Exception('wrong code');
    signedInAs = email;
  }

  @override
  Future<void> submit(String id, Map<String, Object?> data) async {
    if (refuseWith case final error?) throw error;
    sent[id] = data;
  }
}

/// A campaign level under an id the campaign does not use.
Level renamed(Level level, String id) =>
    levelFromJson(level.toJson()..['id'] = id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final good = renamed(Levels.standOnYourself, 'from-the-bench');

  test('a level the gate would refuse is never sent', () async {
    final backend = FakeBackend()..signedInAs = 'me@example.com';
    // The bench level: nothing recorded, nothing to replay.
    final result = await LevelUpload(backend).send(Levels.lab);

    expect(result, isA<RefusedHere>());
    expect((result as RefusedHere).reasons, contains('cannotBeChecked'));
    expect(backend.sent, isEmpty);
  });

  test('neither is a level under a campaign id', () async {
    final backend = FakeBackend()..signedInAs = 'me@example.com';
    final result = await LevelUpload(backend).send(Levels.goInLow);

    expect((result as RefusedHere).reasons, contains('campaign'));
    expect(backend.sent, isEmpty);
  });

  test('a good one asks for a sign-in, then goes as it is', () async {
    final backend = FakeBackend();
    final upload = LevelUpload(backend);

    expect(await upload.send(good), isA<NeedsSignIn>());
    expect(backend.sent, isEmpty);

    backend.signedInAs = 'me@example.com';
    final result = await upload.send(good);

    expect((result as Submitted).id, 'from-the-bench');
    expect(backend.sent['from-the-bench'], good.toJson());
  });

  test('the server saying no is shown, not thrown', () async {
    final backend = FakeBackend()
      ..signedInAs = 'me@example.com'
      ..refuseWith = UploadRefused('"from-the-bench" is taken');
    final result = await LevelUpload(backend).send(good);

    expect((result as Failed).message, contains('taken'));
  });

  testWidgets('the dialog, from a passing check to sent', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UploadDialog(level: good, upload: LevelUpload(backend)),
        ),
      ),
    );
    // The check replays the level for real; let it run.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'me@example.com');
    await tester.tap(find.text('send code'));
    await tester.pumpAndSettle();
    expect(backend.codes, ['me@example.com']);

    await tester.enterText(find.byKey(const Key('code')), '000000');
    await tester.tap(find.text('sign in and send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('wrong code'), findsOneWidget);
    expect(backend.sent, isEmpty);

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.tap(find.text('sign in and send'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(backend.sent.keys, ['from-the-bench']);
    expect(find.textContaining('Sent as me@example.com'), findsOneWidget);
  });
}
