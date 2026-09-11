# خطة Phase 1 لبناء الـ Environment/Art Foundation للعبة Side-Scroller مصرية بالـ Flutter + Flame

## TL;DR
- **آه، تقدر تعمل مشروع واحد يشتغل على موبايل + desktop + web من كود واحد بالـ Flame 1.38.2، بس الـ web هو نقطة الضعف**: الـ CanvasKit بيضيف ~1.5MB تحميل أولي قبل حتى الأصول (وحسب Flutter docs: "includes a copy of Skia compiled to WebAssembly, which adds about 1.5MB in download size")، والـ fragment shaders على الويب متقلبة تاريخيًا (اتكسرت أكتر من مرة)، فلازم تعامل الـ web كـ "nice to have" مش كـ blocker.
- **الـ M1 Air بـ 8GB RAM يقدر يعمل Blender Eevee بشكل معقول بس مش Cycles**؛ والأذكى في Phase 1 إنك تبدأ بـ **تصوير أماكن مصرية حقيقية وتحويلها لـ silhouettes** بدل ما تضيّع أسابيع في نمذجة 3D — ده أسرع طريق لنتيجة حلوة لواحد مش رسّام.
- **Phase 1 = 5 جُمَع (Fridays)، مشهد مصري واحد جميل بيتمشى فيه character والكاميرا بتتبعه، بدون أي gameplay** — والـ risk الأكبر هو الـ web عبر الأجهزة والـ shaders، فاعمل الـ atmosphere بطبقات PNG وblend modes الأول والـ shaders آخر حاجة.

## Key Findings

1. **Flame النسخة الحالية 1.38.2** (اتنشرت 27 أغسطس 2026) وبتطلب Flutter حديث نسبيًا — الـ changelog الأخير فيه بالنص `FIX: Bump Flutter min version to 3.41.0 (#3807)` — وDart SDK constraint `>=3.0.0`. Flame رسميًا بيدعم web + mobile + desktop لكن على الـ **stable channel بس**.
2. **الـ web شغّال بس بتنازلات**: الـ default build بيستخدم CanvasKit (بيضيف ~1.5MB)، والـ `--wasm` build بيستخدم skwasm (~1.1MB، أخف وبيرندر على thread تاني) بس بيحتاج WasmGC وheaders COOP/COEP على السيرفر عشان الـ multithreading. الـ HTML/DOM renderer **اتـ deprecate في 3.19 واتشال خالص في 3.22** — يعني كل تطبيقات الـ web دلوقتي بتستخدم skwasm أو CanvasKit.
3. **الـ fragment shaders خطر على الـ web**: `FragmentProgram.fromAsset` بيشتغل على CanvasKit نظريًا لكن فيه تاريخ من الـ bugs (اتكسر في 3.19.0، وفشل على mobile web في issues موثّقة). على mobile/desktop أأمن بكتير.
4. **Flame عنده دلوقتي post-processing pipeline فعلي** (`PostProcess` + `PostProcessComponent`) بيعمل bloom/color grading/pixelation عبر shaders — بس نفس تحذير الـ web ينطبق.
5. **الـ Blender-to-2D pipeline واقعي على M1** لو استخدمت **Eevee** (real-time rasterizer) مش Cycles (path tracer بطيء جدًا على Mac CPU — في تقارير 4-5 ساعات للفريم الواحد).
6. **المراجع البصرية المصرية موجودة وقوية**، وأهم اكتشاف: **مفيش لعبة معروفة متعملة عن القاهرة المعاصرة working-class** — المساحة دي فاضية تقريبًا، أقرب حاجة لعبة سباق توك توك اسمها "Toktok Drift".

## Details

### 1) Flame Cross-Platform Reality Check

**النسخة والإصدارات:** آخر نسخة stable على pub.dev هي **flame 1.38.2** اتنشرت 27 أغسطس 2026، من الـ verified publisher flame-engine.org. الـ changelog الأخير فيه بالنص `FIX: Bump Flutter min version to 3.41.0 (#3807)` يعني لازم Flutter حديث. Dart SDK constraint `>=3.0.0`. Flame بيصرّح رسميًا إنه بيدعم web, Android, iOS, Windows, macOS, Linux — بس **بيسنّد على الـ stable channel بس**، وأي مشاكل بره الـ stable مش أولوية عندهم.

**الـ WEB — الحالة العملية:**
- الـ **default build** بيختار CanvasKit runtime — وحسب توثيق Flutter الرسمي: "includes a copy of Skia compiled to WebAssembly, which adds about 1.5MB in download size". الـ **`--wasm` build** بيختار skwasm (الـ docs بتقول "about 1.1 MB download, versus 1.5 MB for CanvasKit"، وبيرندر على web worker thread منفصل) وبيقع على CanvasKit لو الـ browser مش بيدعم WasmGC.
- الـ WasmGC مدعوم في Chrome 119+, Firefox 120+, Edge 119+, وSafari **18.2+** — وحسب تقرير benchmark أوائل 2026: "That covers roughly 92% of global browser traffic".
- الـ HTML/DOM renderer القديم **اتـ deprecate في Flutter 3.19 واتشال في 3.22** — مبقاش خيار خالص.
- عشان الـ skwasm multithreading يشتغل لازم السيرفر يبعت headers الـ COOP وCOEP، وإلا بيقع single-threaded أو بيفشل.
- **مشاكل معروفة:** الـ CanvasKit عنده initial load time عالي (شكوى قديمة موثّقة في flutter issue tracker)، وأداء ضعيف على resolutions عالية (4K حوالي 20FPS في تقرير موثّق)، وفيه تاريخ من bugs الـ SpriteAnimationComponent مش راندر على الـ web، والـ fragment shaders اتكسرت على الـ web في نسخ Flutter مختلفة.
- **الحكم:** مشهد parallax + fog بطبقات PNG وparticles **واقعي على الـ web في 2026** لو خفّفت عدد الطبقات والـ resolution؛ بس مشهد كله shaders ثقيلة → متعوّلش عليه على الـ web.

**الـ DESKTOP (macOS/Windows/Linux):** أنضج بكتير من الـ web. الـ input فيه keyboard (`KeyboardEvents` mixin / `HardwareKeyboardDetector`) وgamepad (`flame_gamepads` + `gamepads` package اللي بيدعم كل الـ platforms). الـ macOS build هيشتغل native على الـ M1 من غير مشاكل تُذكر.

**اللي بيختلف عبر الـ 3 targets:**
- **Input:** موبايل = touch (`TapCallbacks`, `DragCallbacks`, `JoystickComponent`)؛ desktop/web = keyboard + mouse + gamepad. لازم تعمل abstraction layer للـ input من الأول.
- **Audio:** `flame_audio` (على `audioplayers`) بيشتغل على الكل بس الـ web عنده autoplay restrictions (المتصفح بيمنع الصوت قبل أول interaction من المستخدم).
- **Asset loading:** نفس الـ API، بس الـ web بيحمّل الأصول عبر الشبكة (مش من الـ disk) فحجم الأصول بيأثر على الـ load time مباشرة.
- **Aspect ratios/safe areas:** الموبايل طويل (19.5:9) والـ desktop عريض (16:9) — ده أكبر تحدي تصميمي (شوف قسم 2).

**هل كود واحد يشحن للـ 3؟** آه، بس التنازل الأساسي إنك تصمّم للـ input abstraction من الأول، وتقبل إن الـ web هيبقى أبطأ في التحميل وأقل ثباتًا في الـ shaders.

### 2) Asset Specification عبر الـ 3 Platforms

**الـ design resolution:** استخدم **base logical resolution ثابتة** زي 1280×720 (أو 1920×1080) وسيب Flame يـ scale. أفضل API دلوقتي هو `CameraComponent.withFixedResolution(width: ..., height: ...)` اللي بيعمل نفس دور الـ `FixedResolutionViewport` القديم.

**التعامل مع aspect ratios المختلفة في side-scroller:**
- `FixedResolutionViewport`: بيحافظ على الـ resolution والـ aspect ratio بـ **black bars (letterboxing)** — أضمن حل، بس بيدي حواف سودا على الأجهزة اللي مش بنفس النسبة.
- `MaxViewport` (الـ default): بياخد كل مساحة الـ canvas — أحسن للـ side-scroller لأنك تعرض **عالم أوسع** على الشاشات العريضة (extended viewport) بدل الـ bars.
- `FixedAspectRatioViewport`: بيتمدد محافظًا على النسبة.
- **التوصية:** للـ side-scroller الأتموسفيري، استخدم `MaxViewport` مع تثبيت الـ **ارتفاع** (world height ثابت) وسيب العرض يتمدد — كده الموبايل الطويل يبان أضيق أفقيًا والـ desktop العريض يبان أوسع، من غير letterboxing قبيح. خلّي الـ parallax layers أعرض من الشاشة عشان متبانش حوافها.

**حدود الـ texture atlas الآمنة:** الـ **2048×2048 هو الـ max الآمن عبر كل موبايلات** (فيه أجهزة budget بتنزّل الـ 4096 تلقائيًا وتطلع blurry). خلّي كل atlas **power-of-two (POT)**. الـ 4096 للـ hero art بس (backgrounds كبيرة) وعلى أجهزة متأكد إنها بتدعمه. اقسم الـ atlases per-scene بدل atlas واحد عملاق.

**الـ memory budget:** على الموبايل خلّي إجمالي الـ texture memory تحت 512MB، وخُد بالك من قاعدة Flutter إن إجمالي الـ image cache المفروض ميعديش ~100MB في الـ session الواحدة.

**الـ asset budget للـ web:** عشان build يحمّل في وقت معقول، استهدف **إجمالي أصول أولية صغير قدر الإمكان** (فوق الـ 1.5MB بتاع الـ engine نفسه)، وحمّل باقي المشاهد lazy. استخدم WebP وpreload بس اللي بيبان في أول شاشة.

**الـ format:** Flutter بيدعم **WebP out of the box على كل الـ targets** (PNG, JPEG, WebP, GIF, BMP, WBMP). التوصية: **PNG للـ sprites اللي محتاجة transparency حادة وجودة عالية** (الشخصية والطبقات القريبة)، و**WebP (lossy) للـ backgrounds الكبيرة** عشان يقلل الحجم بشكل كبير خصوصًا للـ web.

### 3) الـ Blender → 2D Sprite Pipeline

**الإعداد للـ parallax layers:**
- اختار الكاميرا → Camera tab → Lens → **Orthographic** (عشان الطبقات متتشوهش بالـ perspective وتفضل flat زي 2D).
- ارندر كل depth layer (foreground / midground / background) في pass منفصل بـ **transparent PNG** (فعّل الـ Film → Transparent، وفي الـ output خلّي RGBA).
- خلّي كل layer على مسافة Z مختلفة وحافظ على نفس الـ ortho scale عشان الـ parallax يقرأ صح لما تحطهم في `ParallaxComponent`.

**اللوك الـ silhouette/backlit/volumetric في Blender:**
- خلّي **light واحد قوي ورا الـ subject** (backlight) عشان الشخصية والعناصر تطلع silhouette أسود.
- الـ volumetric fog/god rays في Eevee: فعّل الـ Volumetrics في render properties، وحط cube كبير بـ **Principled Volume** material حواليه، والـ spotlight ورا الضباب → بيطلع beams/god rays. استخدم Noise Texture + Color Ramp للكثافة.
- **Eevee vs Cycles على M1 Air fanless:** استخدم **Eevee** (real-time rasterizer، بيستغل الـ GPU، سريع). **Cycles path tracer بطيء جدًا على Mac** (في تقارير على Blender Artists بتقول 4-5 ساعات للفريم على CPU default settings). تحذير: فيه bug متسجّل رسميًا (Blender issue #127579) إن Eevee في Blender 4.2 بقى أبطأ من Cycles على أجهزة M1 في مشاهد ثقيلة — فاختبر نسختك قبل ما تعوّل عليها.

**رندر الـ animation cycle لـ sprite sheet:** فيه add-ons جاهزة:
- **theloneplant/blender-spritesheets** (بيصدّر 3D animation لـ sprite sheet + JSON sidecar).
- **Get Sheet Done** (Kilbee) — بيرندر من كام كاميرا ويعمل sheets grid-based.
- **Spritesheet Renderer** و**SpriteAtlasAddon** (Mattline1) — بيدوّروا الأوبجكت أوتوماتيك ويطلعوا JSON.
- البديل اليدوي: ارندر الـ frames كـ PNG sequence وادمجهم بـ ImageMagick montage أو TexturePacker.

**هل تتخطى Blender في Phase 1 وتستخدم تصوير حقيقي؟** — **آه، ده أحسن قرار ليك في Phase 1.** المقارنة الصادقة لواحد مش رسّام:
- **Photo-based (تصوير أماكن مصرية حقيقية → تحويل لـ silhouette):** أسرع طريق لنتيجة حلوة. انت عايش في مصر، تصوّر سطح/حارة حقيقية، تعمل threshold/cutout في Photoshop/GIMP/Photopea → طبقة silhouette فورًا. الـ silhouette art style بيخفي إن الأصل صورة. **الأنسب ليك.**
- **3D-rendered (Blender):** بيدي تحكم كامل في الإضاءة والـ god rays والـ parallax، بس منحنى تعلّم حاد ووقت رندر على M1. اتركه لـ Phase لاحق أو للعناصر اللي محتاجة إضاءة ديناميكية.
- **Hand-drawn:** أحلى لوك لكن محتاج مهارة رسم انت مش موصّفها.
- **التوصية:** Phase 1 = photo-to-silhouette. Blender حاجة تانية بعد ما المشهد الأساسي يشتغل.

### 4) تحقيق الـ Atmosphere في Flame

- **Parallax:** استخدم `loadParallaxComponent([ParallaxImageData('bg.png'), ParallaxImageData('trees.png')], baseVelocity: Vector2(20,0), velocityMultiplierDelta: Vector2(1.8, 1.0))` وضيفه للـ `camera.viewport` (عشان يفضل ثابت بالنسبة لباقي اللعبة).
- **Particles (dust motes/fog):** `ParticleSystemComponent(particle: Particle.generate(count: 10, generator: (i) => AcceleratedParticle(acceleration: ..., child: CircleParticle(paint: ...))))`. كل particle عنده `lifespan` بيشيل الـ component تلقائيًا لما يخلص.
- **Sprite animation:** `SpriteAnimation.fromFrameData(image, SpriteAnimationData.sequenced(amount: 8, stepTime: 0.1, textureSize: Vector2(64,64)))`، وللشخصية اللي ليها حالات استخدم `SpriteAnimationGroupComponent`.
- **Fragment shaders:** عبر Flutter `FragmentProgram.fromAsset('shaders/x.frag')`، وتُعرّف في `pubspec.yaml` تحت `shaders:`. Flame عنده دلوقتي `PostProcessComponent` + `PostProcess` abstract class لعمل bloom/color grading/vignette. **بيشتغل كويس على mobile/desktop، لكن خطر على الـ web** (تاريخ bugs موثّق).
- **الأداء:** على موبايلات mid-range Android، الـ shaders فيها shader compilation jank (أول مرة يتشغّل الـ effect بيعمل stutter). الـ particles كتير بتاكل CPU. الـ parallax بطبقات PNG رخيص جدًا.
- **الحيل الرخيصة (بدون shaders):** الـ god rays = طبقة PNG شفافة نص-شفافة بـ `BlendMode.plus`/`screen` فوق المشهد؛ الـ fog depth = طبقات ضباب PNG بـ opacity متدرجة بتتحرك ببطء؛ الـ bloom = نسخة blurred من مصدر الضوء بـ additive blend؛ الـ vignette = PNG واحد أسود بحواف شفافة فوق كل حاجة. **دي كلها cross-platform 100% وبتشتغل على الـ web من غير قلق.**

### 5) المراجع البصرية للمساحة الحضرية المصرية المعاصرة

**الموتيفات اللي بتقرأ حلو كـ silhouettes:** عناقيد أطباق الدش المتشابكة، خزانات المياه (tanks) الأسطوانية على السطح، حبال الغسيل، الهوائيات القديمة، المآذن في skyline حديث، الأسلاك الكهربائية المتشابكة، السلالم الحلزونية في بيوت السلّم، البلكونات الضيقة بالغسيل، التوك توك، الميكروباص، عربيات الفول/الكارو، المباني الطوب الأحمر غير المكتملة بالـ rebar المكشوف (عشوائيات — الوصف المعماري الرسمي "concrete frame with brick infill")، المشربيات الخشبية.

**مصادر بصرية حقيقية بأسماء وروابط:**
- **Randa Shaath — "Under the Same Sky: Rooftops of Cairo" (تصوير 2002–2003)**: أهم سلسلة أبيض-وأسود عن سكان أسطح القاهرة (دش، غسيل، حياة يومية). اتنشرت كـ monograph من Witte de With Publishers 2004 (بالتعاون مع Fundació Antoni Tàpies، 128 صفحة / 90 صورة duotone أبيض-أسود، مقالة لـ Nadia Kamel، ISBN 9789073362604). Shaath (مواليد 1963) اشتغلت مع AFP وكانت Photo Editor في جريدة الشروق. thephotographersgallery.org.uk + lensculture.com.
- **David Sims — "Understanding Cairo: The Logic of a City Out of Control" (AUC Press, 2010)**: المرجع الأساسي لدقّة العمارة العشوائية.
- **Cairo Bats collective — "Act 1: The Roof" (2015)** في الـ Contemporary Image Collective (CIC) — تدخّلات مسرحية على الأسطح. aperture.org/editorial/dispatches-cairo.
- **Everyday Cairo (@everydaycairo)** على Instagram — أسّسها Mattias Pruym 2014، حياة يومية street-level.
- **David Degner's "My Favorite Egyptian Photographers"** (daviddegner.com/blog/egypt-photographers) — دليل مصوّرين مصريين شغّالين: Eman Helal, Roger Anis, Hesham Elsherif, Ahmed Gaber.
- **Cairobserver (Mohamed Elshahed)** — مدوّنة عن عمارة وعمران القاهرة.
- ستوك: Dreamstime/Alamy فيهم مجموعات "Cairo rooftops" كبيرة كـ reference سريع.

**أعمال موجودة في نفس المساحة (عشان تعرف الـ territory):**
- **Comics:** "Metro" لـ Magdy El Shafee (2008، أول رواية مصوّرة عربية للكبار، نوار في قاهرة معاصرة) — أقوى مرجع للحارة/المترو/الشارع بالأبيض والأسود. **اتمنعت في مصر يناير 2008 بتهمة "خدش الحياء العام"**؛ البوليس داهم دار نشر ملامح، والفنان والناشر محمد الشرقاوي اتحاكموا تحت المادة 178 من قانون العقوبات وكل واحد اتغرّم 5000 جنيه. ومجلة **TokTok** (2011، Andeel/Makhlouf/Shennawy) عن حياة القاهرة.
- **أفلام:** "Poisonous Roses / ورد مسموم" (2018، Ahmed Fawzi Saleh) في منطقة المدابغ (طوب أحمر، حواري ضيقة) — أقرب مرجع بصري للحارة/العشوائيات؛ "Cairo Drive" (2013) عن الميكروباص والزحمة؛ "Sheikh Jackson" (2017)؛ "Ali, the Goat and Ibrahim" (2016).
- **Games:** **مفيش لعبة معروفة عن القاهرة المعاصرة working-class** — المساحة فاضية، أقرب حاجة لعبة سباق توك توك "Toktok Drift" من استوديو Appsinnovate المصري. **ده ميزة تنافسية ليك.**

**الأخطاء الثقافية اللي تتجنّبها:**
- كلمة **"عشوائيات" (ashwa'iyat = عشوائي/فوضوي) نفسها stigmatizing** — النقد الأكاديمي (زي "Informality as Speech Act") بيفضّل كلمة **"شعبي" (sha'bi)** اللي بتدّي كرامة للناس بدل ما توصمهم بالفوضى.
- **تجنّب الـ poverty-tourism/orientalism**: حادثة صورة National Geographic (Rena Effendi 2018) لأسطح فيها غنم أثارت غضب مصريين لأنها بتعرض "الجزء الوحش" — خليها حالة تحذيرية. الحل: صوّر المكان بكرامة وحميمية مش كـ "غرابة" أو بؤس للفرجة.
- بلاش تخلط بين المعاصر والفرعوني (ده اللي رفضته أصلًا وصح). ملاحظة مهمة: معظم دراسات العمران بتقول العشوائيات دي **مبنية كويس** (تلتين سكان القاهرة عايشين فيها، مش favelas) — فاعرضها كمكان حي محترم مش خرابة.

### 6) خطة الـ Phase 1 (5 جُمَع — Environment فقط)

**الهدف النهائي:** مشهد مصري واحد جميل (سطح قاهري وقت الغروب مثلًا) بيتمشى فيه silhouette character والكاميرا بتتبعه، بيشتغل على موبايل + desktop + web.

- **Friday 1 — Setup + skeleton (منخفض الخطورة):** ثبّت Flutter + Flame 1.38.2، اعمل project، شغّل `FlameGame` فاضية على الـ 3 targets (`flutter run -d chrome`, `-d macos`, وموبايل). الـ deliverable/TikTok: "نفس الكود شغّال على 3 شاشات" — لقطة قوية.
- **Friday 2 — Parallax background من صور حقيقية (متوسط):** صوّر/جهّز 3-4 طبقات silhouette لسطح قاهري (سما بالغروب، مباني بعيدة، دش+خزانات قريبة، حبل غسيل foreground)، حوّلهم PNG شفاف، حطهم في `ParallaxComponent`. Deliverable: مشهد بيتحرك بعمق.
- **Friday 3 — Character + camera follow (متوسط، ممكن يعدّي):** silhouette character بـ `SpriteAnimationComponent` (walk cycle بسيط)، حركة يمين/شمال، `camera.follow(player)`، **input abstraction** (keyboard على desktop، touch على موبايل). Deliverable: شخصية بتتمشى في المشهد.
- **Friday 4 — Atmosphere بالحيل الرخيصة (متوسط):** dust particles بـ `ParticleSystemComponent`، god-ray PNG بـ additive blend، fog layers متحركة، vignette overlay. **من غير shaders**. Deliverable: المشهد بقى "atmospheric" فعلًا — أقوى لقطة TikTok.
- **Friday 5 — Polish + web hardening + shaders اختياري (عالي الخطورة، متوقع يزيد):** color grading، اختبار الأداء على الـ 3، لو لسه فيه وقت جرّب `PostProcessComponent` bloom بس على mobile/desktop. **الـ web hardening والـ shaders هما اللي هيعدّوا الوقت.** Deliverable: build نهائي على الـ 3 + فيديو.

**Sessions خطرة:** Friday 5 (الـ web + shaders) و Friday 3 (الـ input abstraction عبر platforms) هما الأرجح يعدّوا الوقت. لو ضغطت، اقطع الـ shaders تمامًا من Phase 1.

### 7) قائمة الـ Install/Setup للـ M1 Air

- **Flutter SDK** (نسخة تدعم Flame 1.38.2، يعني 3.41+) — Apple Silicon native، نزّل الـ arm64 build.
- **Xcode** (من App Store) + CocoaPods — ضروري للـ iOS/macOS builds على الـ M1.
- **Android Studio** + Android SDK — للـ Android build والـ emulator (استخدم arm64 system images عشان تشتغل native على M1).
- **Chrome** — للـ web debugging.
- **flame: ^1.38.2** في pubspec؛ وحسب الحاجة: `flame_audio`, `flame_gamepads`/`gamepads`, `flame_texturepacker`.
- **Blender** (نسخة LTS حديثة) — arm64 native للـ Apple Silicon؛ + add-on زي **Get Sheet Done** أو **theloneplant/blender-spritesheets** لو رحت مسار الـ 3D.
- **محرر صور**: Photopea (مجاني، browser) أو GIMP (arm64) أو Photoshop — لتحويل الصور لـ silhouettes.
- **TexturePacker** (اختياري) لعمل atlases + `flame_texturepacker`.
- **ImageMagick** (اختياري، عبر Homebrew) لدمج frames في sprite sheet.
- **Caveats للـ M1/8GB:** الـ 8GB RAM هتضغط لو فتحت Blender + emulator + Chrome + IDE مع بعض — اقفل اللي مش محتاجه. متعتمدش على Cycles. لو الـ web build بطيء، اختبر عبر `flutter build web` وسيرفر محلي بدل الـ debug mode.

## Recommendations

1. **دلوقتي:** ثبّت الـ toolchain واعمل الـ hello-world على الـ 3 targets (Friday 1). لو الـ web build اتعقّد، اشحن موبايل + desktop الأول وأجّل الـ web — **متخليش الـ web يوقف المشروع**.
2. **Phase 1 كله بـ photo-to-silhouette + PNG layers + blend-mode tricks، من غير Blender ومن غير shaders.** ده أسرع طريق لنتيجة TikTok-worthy مع الـ M1 والجمعة الواحدة.
3. **اعمل input abstraction من أول سطر كود** (interface واحدة لـ move-left/right/jump تتوصّل بـ keyboard أو touch أو gamepad) — ده بيوفّر عليك إعادة كتابة لاحقًا.
4. **الـ benchmarks اللي تغيّر القرار:** لو الـ web فرش تحت 30FPS بعد التخفيف، أو الـ initial load عدّى ~10 ثواني → اقطع الـ web من Phase 1 رسميًا. لو Eevee على M1 بيرندر الفريم في أكتر من دقيقتين → سيب الـ 3D خالص. لو الـ shaders كسرت على أي target → شيلها واستخدم الـ PNG-overlay tricks.
5. **متأخر (Phase 2+):** بعد ما المشهد يشتغل، ساعتها تجرّب Blender للعناصر اللي محتاجة god rays ديناميكية، وساعتها بس تفكّر في الـ delayed-shadow mechanic.
6. **ثقافيًا:** استخدم إطار "شعبي" مش "عشوائي"، وصوّر بحميمية مش فرجة. راجع Metro لـ Magdy El Shafee و Randa Shaath كـ north star بصري.

## Caveats
- بعض تفاصيل الأداء (FPS على أجهزة معيّنة، وقت رندر Eevee على M1 تحديدًا) مبنية على تقارير مطوّرين فردية مش benchmarks رسمية — اختبر بنفسك على جهازك.
- حالة الـ fragment shaders على الـ web بتتغير بسرعة مع نسخ Flutter؛ اللي وصفته هنا (تاريخ bugs) صحيح وقت الكتابة بس ممكن يكون اتحسّن — تحقق من آخر issue tracker قبل ما تعوّل عليها.
- الـ min Flutter version لـ Flame ممكن يكون اترفع أكتر؛ اتأكد من الـ `flutter pub get` وقت التثبيت.
- "مفيش لعبة عن القاهرة المعاصرة" استنتاج من بحث، مش إثبات قاطع — ممكن يكون فيه مشاريع صغيرة على itch.io مش ظاهرة في البحث.
- نسبة تغطية الـ 92% من الـ browser traffic لـ WasmGC من تقرير benchmark فردي (flutterstudio.dev) مش مصدر رسمي — خُدها كتقدير.