// The list of app icons the project ships: where each one goes, how big it
// is, and which shape of the mark it wants.
//
// Its own file because two things read it — `tool/icons.dart`, which paints
// them, and `test/ui/app_icons_test.dart`, which checks that what is
// committed still matches this list. A tool that writes files nobody checks
// is a tool whose output quietly rots.

/// One icon file: where it goes, how big, and which shape of the mark.
class Icon {
  const Icon(
    this.path,
    this.size, {
    this.rounded = true,
    this.opaque = false,
    this.maskable = false,
  });

  final String path;
  final int size;

  /// Rounded corners and a hairline, or the full-bleed square a platform
  /// masks for itself. See [GameMark.icon].
  final bool rounded;

  /// Flattened onto its own background, no alpha channel at all.
  ///
  /// iOS rejects an app icon with transparency in it, and a rounded tile has
  /// transparent corners. Those icons are square anyway — iOS rounds them —
  /// so this only matters for the ones that are not.
  final bool opaque;

  /// Drawn inside the maskable-icon safe zone. See [GameMark.icon].
  final bool maskable;
}

const icons = <Icon>[
  // The browser tab, and the web app's own icons. The maskable pair is what
  // Android cuts a circle or a squircle out of when the page is installed, so
  // it is square: a tile that has already rounded its corners loses them.
  Icon('web/favicon.png', 32),
  Icon('web/icons/Icon-192.png', 192),
  Icon('web/icons/Icon-512.png', 512),
  Icon('web/icons/Icon-maskable-192.png', 192, rounded: false, maskable: true),
  Icon('web/icons/Icon-maskable-512.png', 512, rounded: false, maskable: true),

  // Android's launcher icons, one per density. Square for the same reason:
  // the launcher applies the shape.
  Icon(
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    48,
    rounded: false,
  ),
  Icon(
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    72,
    rounded: false,
  ),
  Icon(
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    96,
    rounded: false,
  ),
  Icon(
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    144,
    rounded: false,
  ),
  Icon(
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    192,
    rounded: false,
  ),

  // iOS. Square, and with the alpha channel dropped.
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png',
    20,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png',
    40,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png',
    60,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png',
    29,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png',
    58,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png',
    87,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png',
    40,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png',
    80,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png',
    120,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png',
    120,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
    180,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png',
    76,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png',
    152,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png',
    167,
    rounded: false,
    opaque: true,
  ),
  Icon(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    1024,
    rounded: false,
    opaque: true,
  ),

  // macOS draws the icon it is given, corners and all.
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png', 16),
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png', 32),
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png', 64),
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png', 128),
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png', 256),
  Icon('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png', 512),
  Icon(
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    1024,
  ),
];

/// The sizes inside `windows/runner/resources/app_icon.ico`.
const windowsSizes = [16, 32, 48, 256];
const windowsIco = 'windows/runner/resources/app_icon.ico';
