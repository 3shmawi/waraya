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

/// The release's build number (`release.yml` passes the run number). Zero
/// for a build made anywhere else — which then compares by version alone.
/// A rebuild of the same version is a newer build, and an update.
const int appBuildNumber = int.fromEnvironment('WARAYA_BUILD_NUMBER');
