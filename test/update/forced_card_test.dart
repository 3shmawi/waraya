import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/ui/update_card.dart';
import 'package:waraya/update/update_check.dart';

/// A forced update's card has one way on: the update.
void main() {
  Widget card(String minVersion) => UpdateCard.update(
    lang: Lang.en,
    update: Update(
      published: Published(version: '2.0.0', minVersion: minVersion),
      route: UpdateRoute.download,
      running: '1.0.0',
    ),
    onTake: () {},
    onLater: () {},
  );

  testWidgets('a forced update has no "Later"', (tester) async {
    await tester.pumpWidget(card('2.0.0'));
    expect(find.text('Later'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
    expect(find.textContaining('no longer works'), findsOneWidget);
  });

  testWidgets('an optional one still does', (tester) async {
    await tester.pumpWidget(card(''));
    expect(find.text('Later'), findsOneWidget);
  });
}
