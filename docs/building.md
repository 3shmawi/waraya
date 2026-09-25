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

## تأليف مرحلة من غير ما تعدّل كود

المرحلة بيانات، بس ده مبيبقاش حقيقي غير لما تشوف تعديلك من غير build. الورشة
بتعمل النص التاني من اللوب:

```sh
mkdir -p levels
flutter run -t lib/main_lab.dart --dart-define=WARAYA_LEVELS=levels/
```

- المسار ممكن يبقى **ملف `.json`** أو **فولدر** فيه ملفات، والترتيب بيبقى
  بترتيب الأسامي — يعني تقدر تغيّر الترتيب من غير ما تفتح أي ملف
  (`10-…`, `20-…`).
- **زرار الكود `</>`** بيطبع المرحلة اللي على الشاشة JSON في الكونسول. ده
  نقطة البداية لمرحلة جديدة: محدش بيكتب تلاتين مستطيل من الصفر، بياخد مرحلة
  واقفة ويحرّكها.
- **زرار الفولدر** بيعيد القراية ويبدّل المراحل واللعبة شغالة. مكانك بيتحفظ
  **بالـid**: وانت بتألّف، الليستة هي اللي بتتغيّر طول الوقت (مرحلة بتتحط
  قبلك، واحدة بتتمسح)، فالترتيب معناه إنك تقع في مرحلة تانية كل مرة تدوس
  فيها.
- الغلط بيتقال جنب الزرار نفسه، وبيسمّي **الملف**. وملف مكسور مبيرميش المرحلة
  اللي بتبصّ عليها — وانت بتعدّل، الملف بيبقى مكسور نص الوقت.

الورشة رمادية بقصد (`LevelLook.greyBox`): الشكل الحلو بيجمّل الميكانيكة،
والورشة موجودة عشان تقيس.

### المفردات اللي تحت إيدك

الأساس: `blocks` و`plates` و`doors` و`goal` و`markers` و`spawnX` و`floorTop`
و`delaySeconds` و`shadowIsSolid` و`shadowKills`. وزيادة عليهم:

```json
"toggles": [ { "area": [-320,608,-200,620], "flips": "gate" } ],
"plates":  [ { "area": [-160,608,-40,620], "opens": "gate", "inverts": true } ]
```

- **`toggles` — المفتاح.** بيتقلب على **الحافة**: لحظة ما جسم يدوس عليه، وبس.
  قد ما تقف عليه مش فارق. واللي بيدوس ممكن يكون انت أو ظلك، يعني كل لمسة منك
  بترجع تتلغي بعد `delaySeconds` بالظبط.
- **`plates[].inverts` — الزرار المعكوس.** بيمسك الباب **مقفول** طول ما فيه
  جسم فوقيه، وبيغلب كل حاجة تانية بما فيها `lingerSeconds`.
- الترتيب: معكوس مضغوط → مقفول. زرار عادي مضغوط أو مفتاح مقلوب → مفتوح. غير
  كده → بيقفل بعد `lingerSeconds`.

وكل مرحلة بتطلّع `requires` لوحدها من اللي جواها (`toggles`،
`inverted-plates`)، فاللي عنده بيلد أقدم من المفردة بيرفض المرحلة بالاسم بدل
ما يلعبها ناقصة. الشرح الكامل في `docs/phase-6-vocabulary.md`.

**والمرحلة متتحسبش خلصت** غير لما يبقى معاها حل مسجّل وفكرة غلط مسجّلة
بيتشغّلوا على اللعبة الحقيقية في تست — `test/level/levels_test.dart`.
