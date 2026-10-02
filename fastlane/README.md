fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload an AAB to the internal testing track

### android production

```sh
[bundle exec] fastlane android production
```

Promote a build from internal testing to production

----


## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Sign the built app and upload it to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit a TestFlight build for App Store review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
