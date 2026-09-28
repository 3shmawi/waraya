import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands [json] to the browser as a download called [fileName].
Future<String> saveLevelFile(
  String fileName,
  String json, {
  String? folder,
}) async {
  final blob = web.Blob(
    [json.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
  return 'downloaded $fileName';
}

/// Asks the browser for a file and gives back its text, or null if nothing
/// was picked.
Future<String?> pickLevelFile() {
  final done = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      done.complete(null);
      return;
    }
    file.text().toDart.then(
      (text) => done.complete(text.toDart),
      onError: done.completeError,
    );
  }.toJS;
  input.oncancel = (web.Event _) {
    if (!done.isCompleted) done.complete(null);
  }.toJS;
  input.click();
  return done.future;
}

const bool canPickLevelFile = true;
