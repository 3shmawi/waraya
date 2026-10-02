import 'package:web/web.dart' as web;

import 'update_check.dart';

/// The new game is already on the server; loading the page again is the
/// update.
Future<void> applyUpdate(Update update) async {
  web.window.location.reload();
}
