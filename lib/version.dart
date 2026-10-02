/// Which copy of the game this is.
///
/// [appVersion] is `pubspec.yaml`'s version, written here as a constant
/// because nothing in Flutter reads the pubspec at run time without a
/// plugin. `test/app/version_test.dart` fails the day the two differ, and
/// the `bump` workflow moves both in the same commit.
const String appVersion = '1.0.0';

/// The commit this build was made from, on the web (`pages.yml` passes it).
/// Empty everywhere else: a web page changes on every push to `main`, a
/// phone build only on a version.
const String appBuild = String.fromEnvironment('WARAYA_BUILD');
