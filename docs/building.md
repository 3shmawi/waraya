# Build notes

Two things about this project's builds that cost an afternoon each, kept
out of the README so they are findable rather than skimmed past.

## The bundled font, and why

A web build from 3.44.9 requests
`https://fonts.gstatic.com/s/roboto/v32/...woff2` while starting, and
`--no-web-resources-cdn` does not cover it. Where that fetch is blocked, every
string vanished — the debug HUD drew its panel and no text. Measured, not
assumed: the same commit on 3.47.3 makes no such request and renders the HUD.

**Liberation Mono is now bundled**, so text no longer depends on a CDN. With
the font in the bundle and `fonts.gstatic.com` still blocked, the HUD renders
identically to the 3.47.3 build. The Roboto request still happens — Flutter web
registers it as the engine fallback regardless — but nothing visible depends on
it any more.

**Licence.** `assets/fonts/LiberationMono-Regular.ttf` is copyright (c) 2012
Red Hat, Inc. with Reserved Font Name Liberation, under the SIL Open Font
License 1.1. The full licence text is in
`assets/fonts/LiberationMono-LICENSE.txt`, which ships inside the app bundle
and is registered with Flutter's `LicenseRegistry` in `main.dart`, so it shows
up wherever the app lists its open-source licences. The OFL requires the
licence and copyright notice to travel with the font, which is what that
arrangement is for.

The file is shipped **unmodified and under its original name**, which is what
keeps the reserved-name clause satisfied without renaming.

**Size.** The font is 312 KB raw, about 174 KB gzipped, which roughly doubles
the app's asset payload (304 KB of layers, 644 KB in total). Since web download
size is the plan's main risk, the obvious next step is subsetting it to the
glyphs actually used, which would take it to tens of kilobytes. That is a
modification, so under OFL condition 3 a subset **must be renamed** before it
can be redistributed — it could not still be called Liberation.

## Web builds

```bash
flutter build web --release
```

Add `--no-web-resources-cdn` to bundle CanvasKit locally instead of pulling it
from `gstatic.com` — required behind a restrictive network, and worth measuring
either way since the plan treats web download size as the main risk. A `--wasm`
build (skwasm, ~1.1 MB versus CanvasKit's ~1.5 MB) passes the dry run and is
worth testing once real assets exist.


## إضافة plugin وبناء الويب

لو ضفت dependency فيها plugin (`shared_preferences`، `audioplayers`، أي حاجة
ليها كود native أو web)، **اعمل `flutter clean` قبل ما تبني للويب**.

الـweb plugin registrant بيتولّد مرة وبيتخزّن في `.dart_tool`، وإضافة plugin
جديدة **مش** بتعتبر البيلد القديم باظ. فـ`flutter build web` بيفضل يطلّع bundle
مسجّل فيه الـplugins اللي كانت موجودة **قبل** الإضافة، والنتيجة:

```
MissingPluginException(No implementation found for method getAll
on channel plugins.flutter.io/shared_preferences)
```

الكود سليم، والتستات بتعدّي، والـanalyze نضيف — وبس ميشتغلش في المتصفح.
`flutter clean && flutter pub get && flutter build web` بيحلّها.
