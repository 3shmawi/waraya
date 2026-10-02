# Phase 10 — الصقل والنشر

> الحالة: **الجزء اللي بيتعمل من غير صاحب المشروع اتعمل.** اللي فاضل كله
> قرارات وحسابات باسمه (القسم ٣)، ولعب بإيد على موبايل حقيقي (القسم ٤).

---

## ٠) «النشر» معناه إيه هنا

اللعبة **منشورة أصلاً**: `https://3shmawi.github.io/waraya/` بتتحدّث مع كل
push على `main`، ومن غير تحميل. ده النشر اللي بيهم مشروع بيتنشر على
TikTok — لينك في البايو.

فالـPhase دي مش «أول مرة حد يلعبها». هي تلات حاجات:

1. **إن أي بيلد يطلع من الريبو يبقى اللعبة** — مش مشهد Phase 1، ومش بإمضا
   debug.
2. **إن اللي الستورات هتسأل عنه يبقى موجود وصادق** — صفحة الخصوصية أولهم.
3. **إن نسخة للكمبيوتر والأندرويد تتعمل بـ`git tag`** — مش بعد ظهر كامل على
   جهاز واحد.

والستورات نفسها (Google Play وApp Store) **قرار صاحب المشروع** مش حاجة
بتتعمل من هنا: فيها فلوس (Apple ٩٩ دولار في السنة، Play ٢٥ مرة واحدة)
وحسابات باسمه وموافقات بتاخد أيام.

---

## ١) اللي اتعمل

### ١.١ — `lib/main.dart` بقى اللعبة

**ده كان باج نشر حقيقي، ومحدش كان هيشوفه.** `flutter build apk` و`ipa`
و`macos` و`windows` و`linux` و`web` كلهم بيبنوا `lib/main.dart` لو محدش قال
`-t`، و`main.dart` كان **مشهد Phase 1**: الماشي والأفق ومفيش لغز. البيلد
بينجح، والأبلكيشن بيفتح، وشكله حلو — وهو مش اللعبة. الويب بس كان سليم لأن
`pages.yml` بيقول `-t lib/main_levels.dart` صريح.

- المشهد اتنقل لـ`lib/main_scene.dart`.
- `lib/main.dart` بقى سطر واحد: `export 'main_levels.dart' show main;`.
  و`main_levels.dart` فضل الاسم اللي كل سكريبت ودوك بيستخدمه — مفيش نسختين
  من الحملة.
- `test/app/entry_point_test.dart` بيطلب إن `main` بتاع `main.dart` هو
  **نفس** `main` بتاع الحملة (`identical`).
- اتقاس: `flutter build web` من غير `-t` بقى بيطلّع الحملة.

### ١.٢ — صفحة الخصوصية (`site/privacy.html`)

اتوعدت في `docs/phase-8-server.md` («الستورات هتسأل»). عربي وإنجليزي، وبتقول:
إيه اللي على الجهاز بس (المراحل اللي خلصت، و`device_id`)، إيه اللي بيتبعت
وإمتى — **كل حقل باسمه اللي بيتبعت بيه** — وليه، وإيه اللي السيرفرات نفسها
بتشوفه (عنوان الاتصال، في سجلات عادية)، وإن مفيش طريقة تمسح سطورك لأن مفيش
حاجة بتربطها بيك.

**وليها تست** (`test/app/privacy_test.dart`): بيعمل `Attempt` ويقرا مفاتيح
`toJson()` بتاعته + `device_id`، ويطلب إن كل واحد منهم مكتوب في النص العربي
**وفي** الإنجليزي. أسهل تغيير في التيليمتري هو إنك تزوّد سطر في `toJson` —
والتست ده هو اللي بيقول إن الصفحة لازم تتحرك معاه. صفحة خصوصية اتأخرت عن
الكود أوحش من مفيش.

### ١.٣ — صفحة الهبوط بقت بتقول الحقيقة

كانت لسه بتقول **«خمس مراحل»** وبتشرح لمس المناطق اللي اتشال من Phase 5.
دلوقتي: ستاشر مرحلة، الأزرار المرسومة، `Esc` للقايمة، ولينك للخصوصية
وللنسخ اللي بتتنزّل.

### ١.٤ — اسم الأبلكيشن، والإمضا

- **الاسم على الشاشة الرئيسية «ورايا»** على أندرويد وiOS (كان `waraya`
  و`Waraya`) — زي `short_name` في مانيفست الويب. الديسكتوب فضل `waraya`:
  عنوان شباك بالعربي في `main.cpp` على ويندوز محتاج `/utf-8` في الكومبايلر،
  وده مش صقل يستاهل بيلد مكسور.
- **أندرويد بيتمضي بمفتاح الرفع لو موجود.** `android/app/build.gradle.kts`
  بيقرا `android/key.properties` (في الـ`.gitignore` من الأول)، ولو مش
  موجود بيرجع لمفتاح الـdebug — بيتسطّب عادي وPlay بيرفضه، وده الفشل الصح:
  بصوت عالي، ومش «مفيش APK خالص».

### ١.٥ — `release.yml`: نسخة بـ`git tag`

```sh
# زوّد version في pubspec.yaml الأول (1.0.0+1 → 1.0.1+2)، وبعدين:
git tag v1.0.1 && git push origin v1.0.1
```

- **التاج لازم يطابق `version:`** في `pubspec.yaml`، وإلا مفيش حاجة بتتبني.
  نسخة اسمها v1.1.0 والأبلكيشن بيقول 1.0.0 = رقمين لحاجة واحدة.
- **التستات الأول.** التاج وعد إن الحلول المسجّلة لسه بتحل والأفكار الغلط
  لسه بتفشل؛ لو `flutter test` وقع، مفيش بيلد.
- بعدها أربع بيلدات بالتوازي: **أندرويد** (APK للتسطيب المباشر وAAB لـPlay)،
  **ويندوز** و**لينكس** (zip/tar)، و**ماك** (`.app` في zip بـ`ditto` عشان
  الـsymlinks). وكلهم بيتحطوا على GitHub Release — اللي لينك «نسخة للكمبيوتر
  والأندرويد» في صفحة الهبوط بيروحله.
- **`workflow_dispatch`** بيبني كله من غير release: تجربة جافة، والبيلدات
  بتفضل artifacts على الـrun.

**مش بيتبني هنا:**
- **iOS** — `.ipa` محدش يقدر يسطّبه من غير هوية إمضا وprovisioning profile
  مش نسخة.
- **الويب** — `pages.yml` بينشره مع كل push أصلاً.

**وكله مش ممضي** غير أندرويد (لو فيه مفتاح): ويندوز SmartScreen بيحذّر أول
مرة، وماك Gatekeeper بيمنع الدبل‌كليك (كليك يمين ← Open مرة واحدة). ده مكتوب
في نص الـrelease نفسه، عشان اللي نزّلها ميفتكرهاش مكسورة.

---

## ٢) القواعد

- **كل بيلد بيبني `lib/main.dart`.** متحطش `-t` في `release.yml`: لو
  الـdefault غلط، التست هو اللي يقع، مش سكريبت يستخبى وراه.
- **المفتاح عمره ما يدخل الريبو ولا الشات** — نفس قاعدة الـservice key.
  GitHub Secrets بس، والـkeystore بيتكتب على الديسك طول الجوب وبس.
- **صفحة الخصوصية بتتغيّر في نفس الكوميت** اللي بيغيّر اللي بيتبعت.
- **مفيش SDK تحليلات ولا إعلانات.** اللي بيتبعت هو اللي في الصفحة، ولو
  حاجة اتزوّدت الصفحة بتقول.

---

## ٣) اللي محتاج صاحب المشروع

ولا واحدة من دول تتعمل من سيشن. الحسابين موجودين؛ اللي تحت بالترتيب.

**الـID: `com.mohager.waraya`** — على أندرويد (`applicationId` و`namespace`
و`MainActivity`) وiOS وماك ولينكس. **بعد أول رفع مبيتغيّرش تاني أبداً**: الستور
بيعرف الأبلكيشن بيه، وتغييره = أبلكيشن تاني.

### ٣.١ — مفتاح الرفع بتاع أندرويد (مرة واحدة)

`keytool` جاي مع Java؛ لو مش عندك، Android Studio فيه واحد:
`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool`.

```sh
keytool -genkey -v -keystore ~/waraya-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

بيسأل على باسورد (مرتين) وعلى اسم وبلد — الاسم والبلد مش مهمين ومحدش بيشوفهم.
**خُد نسخة من الملف والباسورد في password manager.** مع Play App Signing
(الـdefault) جوجل هي اللي ماسكة مفتاح الإمضا الحقيقي، وده مفتاح **الرفع** بس —
لو ضاع بيتعمل reset من الـconsole، بس بياخد أيام.

وبعدين الأربع secrets في GitHub (Settings ← Secrets and variables ←
Actions ← New repository secret):

| الاسم | القيمة |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | ناتج `base64 -i ~/waraya-upload.jks \| pbcopy` |
| `ANDROID_STORE_PASSWORD` | باسورد الـkeystore |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | نفس الباسورد (keytool الجديد بيستخدم واحد للاتنين) |

وللبيلد على جهازك: `android/key.properties` (متعملوش commit — في الـ`.gitignore`):

```properties
storeFile=/Users/<انت>/waraya-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

**اتأكد قبل التاج:** Actions ← release ← Run workflow. من غير تاج بيبني كله
ومبيعملش release، والـAAB بيبقى artifact على الـrun. لو التحذير «signing with
the debug key» ظهر، فيه secret ناقص.

### ٣.١ب — بيانات الستور

النصوص كلها (الوصف القصير والطويل بالعربي والإنجليزي، الكلمات المفتاحية،
اللينكات) في `docs/store-listing.md`، متقاسة على حدود كل ستور. والصور
(screenshots لـPlay والآيفون والآيباد، والـfeature graphic) بتترسم من اللعبة
نفسها: `flutter test tool/store.dart` — كل صورة مرحلة ولحظة في حلها المسجّل،
فمفيش صورة بتوري حاجة اللعبة مبقتش بتعملها.

### ٣.٢ — Google Play

1. **Create app** — الاسم «ورايا»، Game، Free. (Free مبيرجعش paid بعد كده.)
2. **App content** — كله إجباري قبل أي نشر:
   - **Privacy policy:** `https://3shmawi.github.io/waraya/privacy.html`
   - **Ads:** لأ.
   - **Content rating** (IARC): مفيش عنف غير إن الشخصية بتموت وترجع، ولا
     تواصل بين لاعبين، ولا شرا. المتوقع PEGI 3 / Everyone.
   - **Target audience:** ‎13+ هو الأسهل. لو اخترت أعمار تحت ١٣، سياسة
     Families بتنطبق، وأي إرسال بيانات بيتراجع بشدة.
   - **Data safety** — من صفحة الخصوصية بالظبط:
     - Collects data: **Yes**. Shared: **No**.
     - **App activity → Other actions**: تفاعل مع اللعبة. **Device or other
       IDs**: الـ`device_id` العشوائي. الاتنين: Analytics، مش مربوطين بهوية،
       مش ephemeral.
     - Encrypted in transit: **Yes** (HTTPS). Deletion request: مفيش حسابات،
       فمش مطلوب.
     - Optional or required: **Required** — مفيش زرار يقفله (القسم ٤).
3. **Store listing:** اسم ≤٣٠ حرف، وصف قصير ≤٨٠، وصف كامل ≤٤٠٠٠، أيقونة
   512×512 (`web/icons/Icon-512.png`)، feature graphic 1024×500، وتليفون
   ٢ screenshots على الأقل (نسبة ≤ 2:1). والإيميل بتاع التواصل **بيظهر للناس**.
4. **الرفع:** Testing ← Internal testing ← Create release ← الـAAB من الـGitHub
   Release. أول رفع بيسألك توافق على Play App Signing: وافق.
5. **لو الحساب شخصي واتعمل بعد نوفمبر ٢٠٢٣:** قبل Production لازم **Closed
   testing بـ١٢ tester على الأقل، ١٤ يوم متواصلين**. ده أطول خطوة في الموضوع
   كله — ابدأها بدري (اللي بيتابعوا على تيكتوك أسهل مصدر).
6. **كل رفع بعد كده** محتاج `versionCode` أكبر: الرقم اللي بعد `+` في
   `pubspec.yaml` (`1.0.0+1` ← `1.0.1+2`).

### ٣.٣ — App Store

محتاج ماك عليه Xcode — مش بيتبني من الـworkflow.

1. **developer.apple.com ← Identifiers ← +** — App ID، الـBundle ID
   `com.mohager.waraya` (Explicit)، ومفيش capabilities محتاجها.
2. **App Store Connect ← Apps ← +** — iOS، الاسم «ورايا» (لازم يكون مش
   محجوز)، Primary language Arabic، الـBundle ID ده، وأي SKU (`waraya`).
3. **التوقيع:** افتح `ios/Runner.xcworkspace` (مش `.xcodeproj`) ← Runner ←
   Signing & Capabilities ← Team = حسابك، و«Automatically manage signing».
4. **البيلد والرفع:**
   ```sh
   flutter build ipa --release
   ```
   وبعدين افتح `build/ios/archive/Runner.xcarchive` (بيفتح في Xcode
   Organizer) ← Distribute App ← App Store Connect. أو ارفع الـ`.ipa` اللي في
   `build/ios/ipa/` بأبلكيشن **Transporter**. سؤال التشفير مش هيتسأل:
   `ITSAppUsesNonExemptEncryption = false` في `Info.plist` (HTTPS من النظام
   بس = معفي).
5. **App Privacy** (نفس صفحة الخصوصية):
   - Data Used to Track You: **لأ** — فمفيش popup بتاع ATT.
   - Data Not Linked to You: **Identifiers → Device ID** و**Usage Data →
     Product Interaction**، الاتنين للـAnalytics.
6. **الباقي:** Privacy Policy URL (نفس اللينك)، **Support URL إجباري**
   (`https://github.com/3shmawi/waraya/issues` أو الصفحة الرئيسية)، Category:
   Games ← Puzzle، Age rating questionnaire (كله None)، وscreenshots:
   **iPhone 6.9"** (1320×2868 أو 1290×2796) إجباري، و**iPad 13"**
   (2064×2752) إجباري برضه لأن الأبلكيشن معمول للآيباد كمان
   (`TARGETED_DEVICE_FAMILY = "1,2"`). لو مش عايز تعمل صور آيباد، الأبلكيشن
   يبقى آيفون بس — ده قرار، ومش هيتعمل من غيرك.
7. **TestFlight الأول:** البيلد بيظهر هناك بعد ربع ساعة تقريباً، جرّبه على
   تليفونك قبل Submit for Review.

**أول تاج:** `version: 1.0.0+1` موجودة، فـ`git tag v1.0.0` بيطلّع أول نسخة
أندرويد. وللـApp Store، نفس الرقم في `flutter build ipa`.

---

## ٤) الصقل اللي لسه — بالترتيب

**٠. زرار يقفل الإرسال.** Play بيسأل «optional or required» وApple
بتسأل برضه؛ النهاردة الإجابة «required». مش إجباري، بس هو اللي بيخلّي
الإجابة الأحسن صادقة.

**١. لعب بإيد على موبايل متوسط.** الجو كله (التراب والضباب والـgod rays)
full-screen overdraw، والفريمات اللي في الريبو **من software renderer ومعناها
صفر** (مكتوبة في الـREADME). محدش قاس فريم على موبايل حقيقي. لو تقيل، الأزرار
بالترتيب: `HazeVeils.count` و`maxOpacity`، بعدين `GodRays.strength`، بعدين
`DustField.motesPerLayer`. **دي الحاجة الوحيدة في القايمة اللي ممكن تكون
باج مش تفصيلة.**

**٢. المحرر لسه محدش بنى بيه مرحلة بإيده** (Phase 9). زي كل حاجة هنا —
التستات بتقول إنه شغال، مش إنه مريح.

**٣. حجم الويب.** اتقاس النهاردة: `main.dart.js` ١.٧ ميجا (٥٢٠ك مضغوط)،
والأصول ٢.٤ ميجا منهم ١.٤ `NOTICES` و٣١٢ك Liberation Mono. الخط ده بيتستخدم
في الأرقام بس (الشاشة وقايمة المراحل)، وتقطيعه (subset) لازم **يتغيّر اسمه** (شرط OFL ٣ —
`docs/building.md`). و`--wasm` لسه متجرّبش.

**٤. صوت.** مفيش كتم. على الموبايل الزرار الجانبي بيكفي؛ على الويب في مكتب مش
بيكفي.

**٥. صور الستور.** `tool/clips.dart` بيرسم فريمات اللعبة الحقيقية PNG — نفس
الأداة تطلّع صور الستور بالمقاسات المطلوبة من غير تصوير شاشة.

وزي كل Phase: **كل جولة لعب حقيقي طلّعت باج مفيش تست مسكه.** والجولة الجاية
المرة دي لازم تبقى على موبايل، مش على اللابتوب.
