import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/lab/lab_settings.dart';
import 'package:waraya/ui/lab_controls.dart';

/// The bench panel's authoring half.
///
/// Only two things here are decisions rather than layout: the re-read button
/// is absent when the bench was not pointed at anything to re-read, and
/// whatever the buttons had to say is shown next to them. The second is the
/// one that matters — authoring in JSON means a mistake is a typo rather than
/// a compile error, and a typo whose only symptom is that the button did
/// nothing is the worst of both.
void main() {
  Widget panel({
    VoidCallback? onReread,
    VoidCallback? onDump,
    String? status,
  }) => MaterialApp(
    home: Scaffold(
      body: LabControls(
        settings: LabSettings(),
        onReload: () {},
        onReread: onReread,
        onDump: onDump,
        status: status,
      ),
    ),
  );

  testWidgets('offers nothing to re-read when there is nothing to re-read', (
    tester,
  ) async {
    await tester.pumpWidget(panel());
    expect(find.byIcon(Icons.folder_open), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and offers it when it was pointed at a folder', (tester) async {
    var reread = 0;
    var dumped = 0;
    await tester.pumpWidget(
      panel(onReread: () => reread++, onDump: () => dumped++),
    );

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.tap(find.byIcon(Icons.code));
    await tester.pump();

    expect(reread, 1);
    expect(dumped, 1);
  });

  testWidgets('says what went wrong where the button is', (tester) async {
    await tester.pumpWidget(
      panel(onReread: () {}, status: 'levels/two.json is not valid JSON'),
    );
    expect(find.text('levels/two.json is not valid JSON'), findsOneWidget);
  });
}
