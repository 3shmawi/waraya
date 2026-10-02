/// Taking an update: a reload on the web, the release page elsewhere.
library;

export 'apply_update_stub.dart'
    if (dart.library.js_interop) 'apply_update_web.dart';
