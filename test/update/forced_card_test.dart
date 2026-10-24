import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/ui/update_card.dart';
import 'package:waraya/update/update_check.dart';

/// A forced update's card has one way on: the update.
void main() {
  Widget card(String minVersion, {UpdateRoute route = UpdateRoute.download}) =>
      UpdateCard.update(
        lang: Lang.en,
        update: Update(
          published: Published(version: '2.0.0', minVersion: minVersion),
          route: route,
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

  testWidgets('from a store the button says update, not download', (
    tester,
  ) async {
    await tester.pumpWidget(card('', route: UpdateRoute.store));
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('from a store that names no version, nothing made up', (
    tester,
  ) async {
    await tester.pumpWidget(
      UpdateCard.update(
        lang: Lang.en,
        update: Update(
          published: const Published(version: ''),
          route: UpdateRoute.store,
          running: '1.1.1',
          fromStore: true,
        ),
        onTake: () {},
        onLater: () {},
      ),
    );
    expect(find.text('A new version'), findsOneWidget);
    expect(find.text('Small fixes.'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
  });
}
