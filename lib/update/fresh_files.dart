/// Which of the files a page has loaded to fetch again, past the browser's
/// cache, before reloading it into a new build.
///
/// A plain reload asks for the page again and nothing else fresh: GitHub
/// Pages lets the browser keep every other file for ten minutes, and the
/// game's own files — `main.dart.wasm`, `main.dart.mjs` and the rest — have
/// the same names in every build. So the reload put the old game back on
/// screen with the new page around it, and the card offering the update
/// came straight back. Reported from waiting for a new level on the bench.
///
/// Every file the page loaded from its own site, once each, without its
/// `#`. Not a list of Flutter's file names: whatever this build loads —
/// the engine, the code, the pictures — is exactly what the next one may
/// have changed, and the browser already knows the list.
List<String> filesToRefresh(Iterable<String> loaded, {required String origin}) {
  final seen = <String>{};
  return [
    for (final url in loaded)
      if (Uri.tryParse(url) case final uri?
          when uri.hasScheme && uri.origin == origin)
        if (seen.add(uri.removeFragment().toString()))
          uri.removeFragment().toString(),
  ];
}
