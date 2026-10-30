# Store listing — ورايا

Everything the Google Play and App Store listings ask for, in Arabic (the
default language) and English (a translation). Copy each block as it is.
Character counts are checked against each store's limit; a store counts
every letter, space and mark.

The images are not committed: they are rendered from the game itself by
`tool/promo/store.js`, in the videos' style — the same sky, the same phone on
its side, the same words (see the end of this file).

---

## Google Play

| Field | Value |
|---|---|
| App name | `ورايا` |
| Category | Game → **Puzzle** (ألغاز) |
| Tags (up to 5) | Puzzle, Platformer, Adventure, Atmospheric, Indie |
| Website | `https://3shmawi.github.io/waraya/` |
| Privacy policy | `https://3shmawi.github.io/waraya/privacy.html` |
| Contains ads | No |
| In-app purchases | No |

### Short description (≤ 80)

**Arabic**

```
ظلك بيعيد كل اللي عملته بعد ثواني. خطّط لماضيك عشان تعدّي.
```

**English**

```
Your shadow repeats everything you did, seconds later. Plan your past to pass.
```

### Full description (≤ 4000)

**Arabic**

```
ورايا لعبة ألغاز عن ظلك: ظل بيعيد كل حاجة عملتها، بعد كام ثانية ثابتة.

انت مش بتتحكم في ظلك. بتتحكم في اللي هيعمله بعد شوية.

لو عايز زرار يفضل مدوس هناك، لازم تروح تقف عليه انت بنفسك قبلها بثواني، وبعدين تمشي وتبقى في مكان تاني لما ماضيك يوصل ويدوسه. فبتقضي اللعبة وانت بتعمل حاجات شكلها ملهاش لازمة، وانت عارف إنها الحل لمشكلة لسه موصلتلهاش.

وظلك مش صورة. هو حاجة حقيقية في الدنيا:
• بيدوس الزراير ويقلب المفاتيح
• توطى، وبعد ثواني يبقى سلّمة تطلع عليها
• يقف في طريقك، ولو لمسك بتبدأ من الأول
• وجوّه النور مش موجود خالص

مفيش زرار تسجيل ومفيش رجوع بالوقت. التأخير شغال طول الوقت، سواء انت جاهز أو لأ، وده اللي بيخلّي الإحساس أقرب لإنك متطارد من إنه لغز هادي.

خمسين مرحلة في تلات فصول:
• الأسطح: الزرار، المنصة، العقبة، التضحية، المفتاح اللي ماضيك بيقلبه تاني، النور، وظلين بتأخيرين مختلفين في نفس الوقت
• بيت السلّم: خمستاشر مرحلة بزرار بيطفي النور
• وفوق السطح تاني: المراية — ماضيك يوصلها، تلاقي نفسك مكانه — والجديد، كلب الشارع: بيجري ورا أي حاجة بتتحرك، وماضيك بيتحرك

وكل جمعة فيه حاجة جديدة.

الصعوبة في الفهم مش في السرعة: مفيش عدّاد بيجري، ومفيش مرحلة بتعاقبك على لحظة تفكير.

المكان مصر المعاصرة، مش مصر القديمة. كل حاجة غامقة في الخلفية صورة فوتوغرافية لمكان حقيقي، متقصوصة ومتحطة في طبقات، في عاصفة تراب وقت الغروب.

• مجانية، من غير إعلانات ومن غير مشتريات
• تقدّمك بيتحفظ: تقفل وترجع تلاقي نفسك مكانك
• أزرار لمس على الشاشة، أو كيبورد
• بتشتغل من غير نت

لعبة من مطوّر واحد، بتتعمل يوم في الأسبوع.
```

**English**

```
Waraya is a puzzle game about your shadow: a shadow that repeats everything you did, a fixed few seconds later.

You do not control your shadow. You control what it will do next.

If you want a plate held down over there, you have to go and stand on it yourself, seconds before you need it — then walk away and be somewhere else when your own past arrives to press it. So you spend the game doing things that look pointless, knowing they are the solution to a problem you have not reached yet.

And your shadow is not a picture. It is a real thing in the world:
• It presses plates and flips switches
• Crouch, and seconds later it is a step you can climb
• It stands in your way, and if it catches you, you start again
• And inside the light, it is not there at all

There is no record button and no rewind. The delay runs whether you are ready or not, which makes it feel closer to being chased than to a quiet puzzle box.

Fifty levels in three chapters:
• The rooftops: the plate, the platform, the obstacle, the sacrifice, the switch your past flips back, the light, and two shadows at two different delays at once
• The stairwell: fifteen levels with a switch that puts the light out
• And back up on the roofs: the mirror — when your past reaches it, you are where it is — and new, the street dog: it runs at anything that moves, and your past moves

And something new every Friday.

The difficulty is in understanding, not speed: no timer running down, and no level that punishes a moment spent thinking.

The setting is contemporary Egypt. Everything dark in the background is a photograph of a real place, cut to a silhouette and layered, in a dust storm at sunset.

• Free, with no ads and no purchases
• Your progress is saved: close it and come back where you were
• On-screen touch buttons, or a keyboard
• Plays offline

Made by one developer, one day a week.
```

### Release notes (≤ 500)

Not here: they are `fastlane/release_notes/ar.txt` and `en.txt`, uploaded
with every build (`fastlane/Fastfile`) and shown in the game's own
«what's new».

### Images

| Asset | Size | File |
|---|---|---|
| App icon | 512×512 | `store/play-icon-512.png` — a full square with no transparency. Play rounds it itself; the web's `Icon-512.png` comes pre-rounded and would be rounded twice. Made by `tool/icons.dart` |
| Feature graphic | 1024×500 | `ar/play/feature-graphic.png`, `en/play/feature-graphic.png` |
| Phone screenshots | 1080×1920 | `ar/play/1-…png` to `6-…png`, and the same in `en/play/` |

Upload the Arabic set to the Arabic listing and the English set to the
English translation (Store listing → Manage translations → English). The
order is the file numbers: the first two are the ones visible without
scrolling, so they are the idea itself — the door your past opened, and the
step that is your own body. The third is what is new.

---

## App Store

| Field | Limit | Value |
|---|---|---|
| Name | 30 | `ورايا` |
| Subtitle (ar) | 30 | `ظلك بيعيد اللي عملته` |
| Subtitle (en) | 30 | `Your shadow repeats you` |
| Primary category | | Games → Puzzle |
| Secondary category | | Games → Adventure |
| Support URL | | `https://3shmawi.github.io/waraya/#contact` |
| Marketing URL | | `https://3shmawi.github.io/waraya/` |
| Privacy policy URL | | `https://3shmawi.github.io/waraya/privacy.html` |

**Keywords** (≤ 100, comma-separated, no spaces after commas — the name and
subtitle are already searched, so they are not repeated here):

```
ar: ألغاز,ظل,منصات,مصر,مغامرة,تفكير,ذكاء,لغز,تأخير,غروب
en: puzzle,platformer,shadow,time,delay,echo,logic,atmospheric,indie,egypt
```

**Promotional text** (≤ 170, can be changed without a new version):

```
ar: جديد: كلب الشارع. بيجري ورا أي حاجة بتتحرك… وماضيك بيتحرك. خمسين مرحلة، من غير إعلانات.
en: New: the street dog. It runs at anything that moves, and your past moves. Fifty levels, no ads.
```

**Description:** the same full descriptions as Google Play.

**Header and Search Results** (the header artwork): `ar/app-store-header/` and
`en/app-store-header/` — **3840×1646** for the slot that takes 5244×2950 or
3840×1646, **3840×2560** for the one that takes 5244×2950, 3840×2560 or
1920×1280, and **5244×2950**, which either slot takes. The same drawing as
Play's feature graphic, laid out for the shape.

**Screenshots:** `ar/iphone/` and `en/iphone/` are 6.9" iPhone at
**1290×2796**, and `ar/iphone-6.5/` and `en/iphone-6.5/` are 6.5" iPhone at
**1284×2778** — App Store Connect shows the 6.5" slot first on some accounts
and refuses the 6.9" size in it; `ar/ipad/` and `en/ipad/` are 13" iPad at **2064×2752**, which
Apple requires while the app still runs on iPad. `ar/iphone-6.3/` and `en/iphone-6.3/` are **1206×2622**, for the
«iPhone with Dynamic Island (medium display)» slot, which takes only that and
1179×2556. `ar/iphone-duo/` and `en/iphone-duo/` are
**2007×2853**, for the iPhone Duo slot (it also takes 1398×2034). Same six moments, same
captions, framed for each shape.

---

## Making the images again

The same footage and the same drawing as the videos
(`docs/marketing/launch-video.md` §٥):

```sh
WORK=/somewhere
for n in 1 2 8 9 15 16; do
  WARAYA_CLIP_SHADOW=0.9 WARAYA_CLIP_DEVICE=844x390@2 WARAYA_CLIP_EVERY=2 \
    WARAYA_CLIP=$n WARAYA_CLIP_OUT=$WORK/frames flutter test tool/clips.dart
done
WARAYA_MARK_OUT=$WORK/mark flutter test tool/promo/mark_frames.dart
node tool/promo/store.js $WORK            # -> $WORK/store/{ar,en}/{play,iphone,iphone-6.3,iphone-6.5,ipad,iphone-duo}
```

Each shot is a clip and a moment in its recorded solution (`SHOTS` in
`tool/promo/store.js`), so a screenshot cannot show a solution the game no
longer accepts; the words are in the same file, in both languages. Everything
is written as RGB with no alpha channel, because Play refuses a screenshot or
a feature graphic that has one. The old portrait ones (`tool/store.dart`, the
game on top and a caption under it) are still there, and no longer used.
